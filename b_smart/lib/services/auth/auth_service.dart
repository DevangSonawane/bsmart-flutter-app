import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/auth/auth_user_model.dart' as model;
import '../../models/auth/signup_session_model.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../config/supabase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   serverClientId: SupabaseConfig.googleWebClientId,
  //   scopes: const ['email', 'openid', 'profile'],
  // );
  final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId:
      '832065490130-97j2a560l5e30p3tu90j9miqfdkdctlv.apps.googleusercontent.com',
  scopes: const ['email', 'profile'],
);

  // In-memory storage for signup sessions during the flow
  final Map<String, SignupSession> _sessions = {};

  AuthService._internal();

  // ==================== SIGNUP METHODS ====================

  // Signup with email - Step 1
  Future<SignupSession> signupWithEmail(String email, String password) async {
    // Check if user already exists (optional, but Supabase signUp will return error/existing user)
    // For now, we just start a session.
    
    final sessionToken = _generateSessionToken();
    final now = DateTime.now();
    
    final session = SignupSession(
      id: sessionToken,
      sessionToken: sessionToken,
      identifierType: IdentifierType.email,
      identifierValue: email,
      verificationStatus: VerificationStatus.pending, // We'll skip OTP for now or mark verified
      step: 1,
      metadata: {
        'email': email,
        'password': password, // Storing temporarily in memory
      },
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    
    _sessions[sessionToken] = session;
    return session;
  }

  // Signup with phone - Step 1
  Future<SignupSession> signupWithPhone(String phone) async {
    final sessionToken = _generateSessionToken();
    final now = DateTime.now();
    
    final session = SignupSession(
      id: sessionToken,
      sessionToken: sessionToken,
      identifierType: IdentifierType.phone,
      identifierValue: phone,
      verificationStatus: VerificationStatus.pending,
      step: 1,
      metadata: {
        'phone': phone,
      },
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    
    _sessions[sessionToken] = session;
    return session;
  }

  // Signup with Google - Step 1
  Future<SignupSession> signupWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in cancelled');
      }
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      if (response.user == null) {
        throw Exception('Supabase sign in failed');
      }

      final sessionToken = _generateSessionToken();
      final now = DateTime.now();
      
      final session = SignupSession(
        id: sessionToken,
        sessionToken: sessionToken,
        identifierType: IdentifierType.google,
        identifierValue: response.user!.email ?? '',
        verificationStatus: VerificationStatus.verified,
        step: 1,
        metadata: {
          'email': response.user!.email,
          'full_name': response.user!.userMetadata?['full_name'],
          'avatar_url': response.user!.userMetadata?['avatar_url'],
        },
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      
      _sessions[sessionToken] = session;
      return session;
    } catch (e) {
      throw Exception('Google sign up failed: $e');
    }
  }

  // Verify OTP - Step 2
  Future<SignupSession> verifyOTP(String sessionToken, String otp) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    // For this implementation, we are skipping actual OTP verification for email/phone 
    // because we want to create the user at the end with all details.
    // If we wanted real OTP, we'd have to use Supabase's verifyOTP, but that requires a user to exist 
    // or a specific OTP flow.
    // We'll assume the client is just simulating the flow or we skip it.
    
    // In a real app with Supabase, you might use 'signUp' (which sends email) then 'verifyOTP'.
    // But here we are collecting info first.
    
    final updatedSession = SignupSession(
      id: session.id,
      sessionToken: session.sessionToken,
      identifierType: session.identifierType,
      identifierValue: session.identifierValue,
      otpCode: otp,
      verificationStatus: VerificationStatus.verified,
      step: 2,
      metadata: session.metadata,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    );
    
    _sessions[sessionToken] = updatedSession;
    return updatedSession;
  }

  // Update session metadata (used in Account Setup)
  Future<void> updateSignupSession(String sessionToken, Map<String, dynamic> updates) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    final newMetadata = Map<String, dynamic>.from(session.metadata);
    if (updates.containsKey('metadata')) {
      newMetadata.addAll(updates['metadata']);
    }

    final updatedSession = SignupSession(
      id: session.id,
      sessionToken: session.sessionToken,
      identifierType: session.identifierType,
      identifierValue: session.identifierValue,
      verificationStatus: session.verificationStatus,
      step: updates['step'] ?? session.step,
      metadata: newMetadata,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    );

    _sessions[sessionToken] = updatedSession;
  }

  // Check username availability
  Future<bool> checkUsernameAvailability(String username) async {
    // Check against public.users table
    final response = await _supabase
        .from('users')
        .select('username')
        .eq('username', username)
        .maybeSingle();
        
    return response == null;
  }

  // Complete signup - Final Step
  Future<model.AuthUser> completeSignup(
    String sessionToken,
    String username,
    String? fullName,
    String? password,
    DateTime dateOfBirth,
  ) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    try {
      User? user;
      final isUnder18 = Validators.calculateAge(dateOfBirth) < AuthConstants.restrictedAge;
      
      if (session.identifierType == IdentifierType.google) {
        // User already exists (signed in via Google)
        // Update their metadata
        final currentUser = _supabase.auth.currentUser;
        if (currentUser == null) throw Exception('User not authenticated');
        
        final updates = {
          'username': username,
          'full_name': fullName,
          'dob': dateOfBirth.toIso8601String(),
          'is_under_18': isUnder18,
          // Trigger expects 'phone' if we have it
          if (session.metadata['phone'] != null) 'phone': session.metadata['phone'],
        };
        
        final response = await _supabase.auth.updateUser(
          UserAttributes(data: updates),
        );
        user = response.user;
        
        // Also ensure public.users is updated (trigger might have run on creation, but we have new data now)
        // The trigger runs on INSERT. For UPDATE, we might need to manually update public.users
        await _supabase.from('users').upsert({
          'id': currentUser.id,
          'username': username,
          'full_name': fullName,
          'date_of_birth': dateOfBirth.toIso8601String(),
          'is_under_18': isUnder18,
          'updated_at': DateTime.now().toIso8601String(),
        });
        
      } else {
        // Email/Password Signup
        // Now we actually create the user in Supabase
        final email = session.metadata['email'];
        final phone = session.metadata['phone'];
        final pass = password ?? session.metadata['password']; // Get from args or metadata
        
        if (email != null) {
          final response = await _supabase.auth.signUp(
            email: email,
            password: pass,
            data: {
              'username': username,
              'full_name': fullName,
              'phone': phone,
              'dob': dateOfBirth.toIso8601String(),
              'is_under_18': isUnder18,
            },
          );
          user = response.user;
        } else if (phone != null) {
           // Phone signup not fully implemented in this snippet, using email as primary
           throw Exception('Phone signup requires Supabase Phone Auth configuration');
        }
      }

      if (user == null) throw Exception('Signup failed');

      // Return AuthUser model
      return model.AuthUser(
        id: user.id,
        username: username,
        email: user.email,
        phone: user.phone,
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        isUnder18: isUnder18,
        avatarUrl: user.userMetadata?['avatar_url'],
        bio: null,
        isActive: true,
        createdAt: DateTime.parse(user.createdAt),
        updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
      );
    } catch (e) {
      throw Exception('Signup failed: $e');
    }
  }

  // ==================== LOGIN METHODS ====================

  Future<model.AuthUser> loginWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) throw Exception('Login failed');
      
      return await _fetchUserProfile(response.user!);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<model.AuthUser> loginWithUsername(String username, String password) async {
    try {
      // 1. Get email for username
      final email = await _supabase.rpc('get_email_by_username', params: {'username_input': username});
      
      if (email == null) {
        throw Exception('Username not found');
      }

      // 2. Sign in with email/password
      final response = await _supabase.auth.signInWithPassword(
        email: email as String,
        password: password,
      );
      
      if (response.user == null) throw Exception('Login failed');
      
      return await _fetchUserProfile(response.user!);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<SignupSession> loginWithPhone(String phone) async {
    // Stub for phone login
    throw Exception('Phone login is not currently supported. Please use Email or Google.');
  }

  Future<void> completePhoneLogin(String sessionToken, String otp) async {
    throw Exception('Phone login is not currently supported.');
  }
  
  Future<void> loginWithGoogle() async {
     try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled');
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) throw Exception('No ID Token found');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      if (response.user == null) throw Exception('Supabase sign in failed');
    } catch (e) {
      throw Exception('Google login failed: $e');
    }
  }

  // Fetch user profile from public.users
  Future<model.AuthUser> _fetchUserProfile(User user) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();
          
      return model.AuthUser.fromJson(data);
    } catch (e) {
      // Fallback if profile doesn't exist (shouldn't happen with trigger)
      return model.AuthUser(
        id: user.id,
        username: user.userMetadata?['username'] ?? 'user',
        email: user.email,
        phone: user.phone,
        fullName: user.userMetadata?['full_name'],
        dateOfBirth: DateTime(2000), // Default
        isUnder18: false,
        avatarUrl: user.userMetadata?['avatar_url'],
        bio: null,
        isActive: true,
        createdAt: DateTime.parse(user.createdAt),
        updatedAt: DateTime.now(),
      );
    }
  }

  // Helper
  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + Random().nextInt(9000)).toString();
  }
}
