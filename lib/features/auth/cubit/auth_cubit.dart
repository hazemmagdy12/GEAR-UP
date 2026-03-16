import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// الإمبورت الطبيعي اهو (من غير alias عشان مش هنحتاجه خلاص)
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_state.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../models/user_model.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial()) {
    getUserData();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final cloudinary = CloudinaryPublic('dfawviyf3', 'zclpevpk', cache: false);
  UserModel? currentUser;
  File? profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickProfileImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        profileImage = File(pickedFile.path);
        emit(ProfileImagePickedSuccess());
      }
    } catch (e) {
      emit(ProfileImagePickedError(e.toString()));
    }
  }

  void clearProfileImage() { profileImage = null; }

  Future<String> _uploadToCloudinary(File image) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, folder: 'user_profiles'),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception("خطأ في رفع الصورة: $e");
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    emit(AuthLoading());
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;

      UserModel userModel = UserModel(
        uId: uid, name: name, email: email, phone: phone, profileImage: '', location: '', createdAt: DateTime.now().toIso8601String(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toMap());

      await CacheHelper.saveData(key: 'is_new_user_$uid', value: true);

      await userCredential.user!.sendEmailVerification();
      currentUser = userModel;
      emit(AuthNeedsVerification());

      _fetchAndSaveLocationSilently();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(AuthLoading());
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        emit(AuthNeedsVerification());
        return;
      }

      String uid = userCredential.user!.uid;
      await CacheHelper.saveData(key: 'uid', value: uid);

      bool isNewUser = CacheHelper.getData(key: 'is_new_user_$uid') ?? false;
      bool surveyCompleted = CacheHelper.getData(key: 'survey_completed') ?? false;

      if (isNewUser && !surveyCompleted) {
        emit(AuthNeedsSurvey(uid));
      } else {
        emit(AuthSuccess(uid));
      }

    } catch (e) {
      emit(AuthError("البريد الإلكتروني أو كلمة المرور غير صحيحة"));
    }
  }

  // 🔥 دالة جوجل (النسخة المتوافقة 100% مع إصدار 7.2) 🔥
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      // 1. تعريف المكتبة بنظام الـ Singleton (بدون أقواس)
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      // 2. تمرير الـ ID الإجباري في دالة التهيئة (initialize)
      await googleSignIn.initialize(
        serverClientId: '533950970964-r7o4d03g7pobe98s0b31haq8ej22gnou.apps.googleusercontent.com',
      );

      // 3. فتح شاشة اختيار حساب جوجل (بالدالة الجديدة authenticate)
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        emit(AuthError('تم إلغاء تسجيل الدخول'));
        return;
      }

      // 4. استخراج التوثيق (idToken فقط لأن الفايربيز مش بيشترط accessToken في التحديث الجديد)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 5. التسجيل في الفايربيز
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      String uid = userCredential.user!.uid;

      // 6. التحقق من المستخدم في الداتابيز
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        UserModel userModel = UserModel(
          uId: uid,
          name: userCredential.user!.displayName ?? 'مستخدم جوجل',
          email: userCredential.user!.email ?? '',
          phone: userCredential.user!.phoneNumber ?? '',
          profileImage: userCredential.user!.photoURL ?? '',
          location: '',
          createdAt: DateTime.now().toIso8601String(),
        );

        await _firestore.collection('users').doc(uid).set(userModel.toMap());

        await CacheHelper.saveData(key: 'is_new_user_$uid', value: true);
        await CacheHelper.saveData(key: 'uid', value: uid);

        currentUser = userModel;
        _fetchAndSaveLocationSilently();

        emit(AuthNeedsSurvey(uid));
      } else {
        currentUser = UserModel.fromJson(doc.data() as Map<String, dynamic>);
        await CacheHelper.saveData(key: 'uid', value: uid);

        _fetchAndSaveLocationSilently();

        bool isNewUser = CacheHelper.getData(key: 'is_new_user_$uid') ?? false;
        bool surveyCompleted = CacheHelper.getData(key: 'survey_completed') ?? false;

        if (isNewUser && !surveyCompleted) {
          emit(AuthNeedsSurvey(uid));
        } else {
          emit(AuthSuccess(uid));
        }
      }
    } catch (e) {
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
        emit(AuthError('تم إلغاء تسجيل الدخول'));
      } else {
        emit(AuthError("حدث خطأ أثناء تسجيل الدخول بجوجل: ${e.toString()}"));
      }
    }
  }

  Future<void> getUserData() async {
    emit(GetUserLoading());
    String? uid = CacheHelper.getData(key: 'uid');
    if (uid != null) {
      try {
        DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          currentUser = UserModel.fromJson(doc.data() as Map<String, dynamic>);
          emit(GetUserSuccess());
          _fetchAndSaveLocationSilently();
        } else { emit(GetUserError('لم يتم العثور على بيانات المستخدم')); }
      } catch (e) { emit(GetUserError(e.toString())); }
    }
  }

  Future<void> _fetchAndSaveLocationSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled(); if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) { return; } }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0]; String currentLoc = "${place.administrativeArea ?? place.locality}, ${place.country}";
        if (currentUser != null && currentUser!.location != currentLoc) {
          String uid = currentUser!.uId; await _firestore.collection('users').doc(uid).set({'location': currentLoc,}, SetOptions(merge: true));
          currentUser = UserModel(uId: currentUser!.uId, name: currentUser!.name, email: currentUser!.email, phone: currentUser!.phone, location: currentLoc, createdAt: currentUser!.createdAt, profileImage: currentUser!.profileImage,);
          emit(LocationFetchedSuccess(currentLoc));
        }
      }
    } catch (e) { print("Location Silent Error: $e"); }
  }

  Future<void> updateUserData({required String name, required String phone, required String email,}) async {
    emit(UpdateUserLoading());
    try {
      String? uid = currentUser?.uId ?? CacheHelper.getData(key: 'uid');
      String currentImageUrl = currentUser?.profileImage ?? '';
      if (uid != null) {
        if (profileImage != null) { currentImageUrl = await _uploadToCloudinary(profileImage!); }
        await _firestore.collection('users').doc(uid).set({'name': name, 'phone': phone, 'email': email, 'profileImage': currentImageUrl,}, SetOptions(merge: true));
        if (currentUser != null) { currentUser = UserModel(uId: currentUser!.uId, name: name, email: email, phone: phone, location: currentUser!.location, createdAt: currentUser!.createdAt, profileImage: currentImageUrl,); }
        clearProfileImage(); emit(UpdateUserSuccess());
      }
    } catch (e) { emit(UpdateUserError(e.toString())); }
  }

  Future<void> logout() async { await _auth.signOut(); await CacheHelper.removeData(key: 'uid'); currentUser = null; clearProfileImage(); emit(AuthInitial()); }
}