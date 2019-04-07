ruleset mapbox_wrapper {
  meta {
    configure using access_token = ""
    shares __testing
    provides getDuration
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    getDuration = function(fromCoordinate, toCoordinate) {
       base_url = <<https://api.mapbox.com/directions-matrix/v1/mapbox/driving/#{fromCoordinate};#{toCoordinate}?access_token=#{access_token}>>;
       response = http:get(base_url);
       status = response{"status_code"};
 
        error_info = {
            "error": "sky cloud request was unsuccesful.",
            "httpStatus": {
                "code": status,
                "message": response{"status_line"}
            }
        };
    
        response_content = response{"content"}.decode();
        response_error = (response_content.typeof() == "Map" && response_content{"error"}) => response_content{"error"} | 0;
        response_error_str = (response_content.typeof() == "Map" && response_content{"error_str"}) => response_content{"error_str"} | 0;
        error = error_info.put({"skyCloudError": response_error, "skyCloudErrorMsg": response_error_str, "skyCloudReturnValue": response_content});
        is_bad_response = (response_content.isnull() || response_content == "null" || response_error || response_error_str);
    
    
        // if HTTP status was OK & the response was not null and there were no errors...
        (status == 200 && not is_bad_response) => response_content | error
    }
  }
  
}
