import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
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

      // 🔥 الحل للمشكلة الأولى: نعلم إن ده يوزر جديد لسه معملش السيرفاي 🔥
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

      // 🔥 نتشيك هل اليوزر ده جديد ولا قديم؟ 🔥
      bool isNewUser = CacheHelper.getData(key: 'is_new_user_$uid') ?? false;
      bool surveyCompleted = CacheHelper.getData(key: 'survey_completed') ?? false;

      if (isNewUser && !surveyCompleted) {
        // لو جديد ومعملش السيرفاي، نخليه الـ State تقول إنه محتاج السيرفاي
        // (لازم تروح في شاشة اللوجين وتعمل Navigation للـ Survey لو الـ State دي طلعت)
        emit(AuthNeedsSurvey(uid));
      } else {
        emit(AuthSuccess(uid));
      }

    } catch (e) {
      emit(AuthError("البريد الإلكتروني أو كلمة المرور غير صحيحة"));
    }
  }

  // ... (باقي كود الـ AuthCubit زي ما هو بدون تغيير)
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