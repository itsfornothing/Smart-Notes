import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

/// Upload image to Firebase Storage and return the download URL
Future<String?> uploadToFirebaseStorage(File imageFile) async {
  try {
    // Create a unique filename
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    
    // Create a reference to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child(fileName);
    
    // Upload the file
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    
    // Get the download URL
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    print('Error uploading to Firebase Storage: $e');
    return null;
  }
}

/// Upload image to Cloudinary and return the secure URL
Future<String?> uploadToCloudinary(File file) async {
  const cloudName = "dmao35yzf";
  const uploadPreset = "portfolio_unsigned_preset"; // Create in Cloudinary
  
  final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/upload");
  
  try {
    var request = http.MultipartRequest("POST", url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    
    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final responseData = jsonDecode(res.body);
      final imageUrl = responseData['secure_url'] as String?;
      return imageUrl;
    } else {
      print("Cloudinary upload failed: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    print("Error uploading to Cloudinary: $e");
    return null;
  }
}