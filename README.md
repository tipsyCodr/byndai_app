# gridcard

A new Flutter project.

mobile web run cmd: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 

---------server db table---------------

DB_USERNAME=byndaiUser
DB_PASSWORD=ScOts84dwrLL6bbquHyP
https://13.234.231.145:8443/phpmyadmin/index.php

-----------------XXXXX-----------------------------------------

https://auth-db1278.hstgr.io/index.php?route=/&db=u944597293_letsconnect&table=posts
username: u944597293_letsconnect
password: 

----------------------------XXXXXX-------------------------------------------

NFC Implement

Summary - Kaunsa File Kyun:
File	                   Action	            Reason
AndroidManifest.xml	       ✅ Modify	          NFC permission aur intent filter ke liye
pubspec.yaml	           ✅ Add package	  nfc_manager dependency ke liye
nfc_service.dart	       🆕 Create new	   NFC core logic (background listener)
auth_provider.dart	       ✅ Modify	          Login ke baad NFC start karne ke liye
main.dart	               ✅ Modify	          Provider list mein NFC add karne ke liye
home_page.dart	           ✅ Modify	          App open hote hi NFC start karne ke liye
profile_page.dart	       ✅ Already          ready	Connection buttons already hain