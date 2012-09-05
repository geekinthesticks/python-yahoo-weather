;;; google-weather.el --- Fetch Google Weather forecasts.

;; Copyright (C) 2010 Julien Danjou

;; Author: Julien Danjou <julien@danjou.info>
;; Keywords: comm

;; This file is NOT part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; This module allows you to fetch Google Weather forecast from the
;; Internet.
;;
;;; Code:

(require 'url)
(require 'url-cache)
(require 'xml)
(require 'time-date)

(eval-when-compile
  (require 'cl))

(defgroup google-weather nil
  "Yahoo Weather."
  :group 'comm)

(defcustom yahoo-weather-use-https f
  "Default protocol to use to access the Yahoo Weather API."
  :group 'yahoo-weather)

(defconst yahoo-weather-url
  "xml.weather.yahoo.com/forecastrss/"
  "URL of the Yahoo Weather API.")

(defconst yahoo-weather-image-url
  "http://l.yimg.com/us.yimg.com/i/us/we/52"
  "URL prefix for images.")

(defcustom yahoo-weather-unit-system-temperature-assoc
  '(("SI" . "℃")
    ("US" . "℉"))
  "Find temperature symbol from unit system."
  :group 'yahoo-weather)

(defun yahoo-weather-cache-expired (url expire-time)
  "Check if URL is cached for more than EXPIRE-TIME."
  (cond (url-standalone-mode
         (not (file-exists-p (url-cache-create-filename url))))
        (t (let ((cache-time (url-is-cached url)))
             (if cache-time
                 (time-less-p
                  (time-add
                   cache-time
                   (seconds-to-time expire-time))
                  (current-time))
               t)))))

(defun yahoo-weather-cache-fetch (url)
  "Fetch URL from the cache."
  (with-current-buffer (generate-new-buffer " *temp*")
    (url-cache-extract (url-cache-create-filename url))
    (current-buffer)))

(defun yahoo-weather-retrieve-data (url &optional expire-time)
  "Retrieve URL and return its data as string.
If EXPIRE-TIME is set, the data will be fetched from the cache if
their are not older than EXPIRE-TIME seconds. Otherwise, they
will be fetched and then cached. Therefore, setting EXPIRE-TIME
to 0 force a cache renewal."
  (let* ((expired (if expire-time
                      (yahoo-weather-cache-expired url expire-time)
                    t))
         (buffer (if expired
                     (url-retrieve-synchronously url)
                   (yahoo-weather-cache-fetch url)))
         data)
    (with-current-buffer buffer
      (goto-char (point-min))
      (unless (search-forward "\n\n" nil t)
        (error "Data not found"))
      (decode-coding-region
       (point) (point-max)
       (detect-coding-region (point) (point-max) t))
      (set-buffer-multibyte t)
      (setq data (xml-parse-region (point) (point-max)))
      (when (and expired expire-time)
        (url-store-in-cache (current-buffer)))
      (kill-buffer (current-buffer))
      data)))

(defun yahoo-weather-build-url (location &optional language)
  "Build URL to retrieve weather for LOCATION in LANGUAGE."
  (concat "http" (when yahoo-weather-use-https "s") "://" yahoo-weather-url  (url-hexify-string location)
          (when language
            (concat "&hl=" language))))

(defun yahoo-weather-get-data (location &optional language expire-time)
  "Get weather data for LOCATION in LANGUAGE.
See `yahoo-weather-retrieve-data' for the use of EXPIRE-TIME."
  (yahoo-weather-retrieve-data
   (yahoo-weather-build-url location language) expire-time))

(defun yahoo-weather-data->weather (data)
  "Return all weather information from DATA."
  (cddr (assoc 'weather (cdr (assoc 'xml_api_reply data)))))

(defun yahoo-weather-data->forecast-information (data)
  "Return the forecast information of DATA."
  (cddr (assoc 'forecast_information (yahoo-weather-data->weather data))))

(defun yahoo-weather-assoc (key data)
  "Extract value of field KEY from DATA."
  (cdr (assoc 'data (cadr (assoc key data)))))

(defun yahoo-weather-data->city (data)
  "Return the city where the DATA come from."
  (yahoo-weather-assoc
   'city
   (yahoo-weather-data->forecast-information data)))

(defun yahoo-weather-data->postal-code (data)
  "Return the postal code where the DATA come from."
  (yahoo-weather-assoc
   'postal_code
   (yahoo-weather-data->forecast-information data)))

(defun yahoo-weather-data->unit-system (data)
  "Return the unit system used for DATA."
  (yahoo-weather-assoc
   'unit_system
   (yahoo-weather-data->forecast-information data)))

(defun yahoo-weather-data->forecast-date (data)
  "Return the unit system used for DATA."
  (yahoo-weather-assoc
   'forecast_date
   (yahoo-weather-data->forecast-information data)))

(defun yahoo-weather-data->forecast (data)
  "Get forecast list from DATA."
  ;; Compute date of the forecast in the same format as `current-time'
  (let ((date (apply 'encode-time
                     (parse-time-string
                      (concat (yahoo-weather-data->forecast-date data) " 00:00:00")))))
    (mapcar
     (lambda (forecast)
       (let* ((forecast-date (decode-time date))
              (forecast-encoded-date (list (nth 4 forecast-date)
                                           (nth 3 forecast-date)
                                           (nth 5 forecast-date))))
         ;; Add one day to `date'
         (setq date (time-add date (days-to-time 1)))
         `(,forecast-encoded-date
           (low ,(yahoo-weather-assoc 'low forecast))
           (high ,(yahoo-weather-assoc 'high forecast))
           (icon ,(concat yahoo-weather-image-url
                          (yahoo-weather-assoc 'icon forecast)))
           (condition ,(yahoo-weather-assoc 'condition forecast)))))
     (loop for entry in (yahoo-weather-data->weather data)
           when (eq (car entry) 'forecast_conditions)
           collect entry))))

(defun yahoo-weather-data->forecast-for-date (data date)
  "Return forecast for DATE from DATA.
DATE should be in the same format used by calendar,
i.e. (MONTH DAY YEAR)."
  (cdr (assoc date (yahoo-weather-data->forecast data))))

(defun yahoo-weather-data->temperature-symbol (data)
  "Return the temperature to be used according in DATA.
It uses `yahoo-weather-unit-system-temperature-assoc' to find a
match."
  (cdr (assoc (yahoo-weather-data->unit-system data) yahoo-weather-unit-system-temperature-assoc)))


(defun yahoo-weather-data->problem-cause (data)
  "Return a string if DATA contains a problem cause, `nil' otherwise.

An error message example:

((xml_api_reply
  ((version . \"1\"))
  (weather
   ((module_id . \"0\") (tab_id . \"0\") (mobile_row . \"0\")
    (mobile_zipped . \"1\") (row . \"0\") (section . \"0\"))
   (problem_cause ((data . \"Information is temporarily unavailable.\"))))))))"
  (yahoo-weather-assoc
   'problem_cause
   (yahoo-weather-data->weather data)))

(provide 'yahoo-weather)
