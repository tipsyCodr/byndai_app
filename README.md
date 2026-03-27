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

//==============================  User Subscription  Model===============================================

1.user automatic free plan subscrib:
   when new user  rigister then after save user data in user table then user automatic subscribe free plan  in direct backend authApiController -->> function registration -->set user free subscription

2.after mobile no. login user get subscription model with subscription data 

a.)auth_provider.dart--->>_processSuccessfulLogin--->>call (_fetchSubscriptionDetails)--->getSubscriptionDetails--->>$_baseUrl/user/subscription(get)--->>return user aur all subscription detail----->>auth provider variable _subscriptionDetails store subscription details

b.)auth_provider.dart--->>loadUserFromStorage--->>call (_fetchSubscriptionDetails)--->getSubscriptionDetails--->>$_baseUrl/user/subscription(get)--->>return user aur all subscription detail----->>auth provider variable _subscriptionDetails store subscription details

c.) any page get access user subscription details by this

    final auth = Provider.of<AuthProvider>(context, listen: false);
    debugPrint("📦 Subscription in HomePage: ${auth.subscriptionDetails}");

3. after google sign in login user get free pln subscribe 
   --->>authApiController--->> public function googleRegister



//==========================payment integration page use==================================
 
   Frontend (Flutter)
    1.SubscriptionPlans.dart / subscription_plan.dart – User ke liye subscription plan cards aur paymentbutton.
    2.razorpay_flutter package – Razorpay ka SDK payment UI aur callback ke liye.
   
   Backend (Laravel)
   
    1.Transaction.php – Model for storing transactions.
    2.TransactionApiController.php – Razorpay order creation, payment verification, aur subscriptionactivation     logic.
    3.UserSubscription.php – User ke active plan store karne ke liye.
    4.SubscriptionPlan.php & PlanFeature.php – Plan aur features detail ke liye.
    5.UserSubscriptionFeature.php – Individual plan features ka tracking.