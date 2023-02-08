import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlng/latlng.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
// import 'package:geocoding/geocoding.dart';
import 'api.dart';

void main() => runApp(MaterialApp(
      home: Home(),
      debugShowCheckedModeBanner: false,
    ));

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  File? image;
  late Uint8List imagebytes;
  late String imageName;
  PickedFile? _pickedFile;
  CloudApi? api;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/credentials.json').then((json) {
      api = CloudApi(json);
    });
  }

  final ImagePicker _picker = ImagePicker();

  //we can upload image from camera or from gallery based on parameter
  Future _pickImage(ImageSource media) async {
    _pickedFile = await _picker.getImage(source: media);

    setState(() {
      image = File(_pickedFile!.path);
      imagebytes = image!.readAsBytesSync();
      imageName = image!.path.split('/').last;
    });
  }

  //show popup dialog
  void myAlert() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text('Please choose media to select'),
            content: Container(
              height: MediaQuery.of(context).size.height / 6,
              child: Column(
                children: [
                  ElevatedButton(
                    //if user click this button, user can upload image from gallery
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        Text('From Gallery'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    //if user click this button. user can upload image from camera
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.camera),
                        Text('From Camera'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  late Position currentPostion;

  void _getUserLocation() async {
    // var position = await GeolocatorPlatform.instance
    //     .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    // setState(() {
    //   currentPostion = LatLng(position.latitude, position.longitude);
    // });
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.

        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.

    var position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      currentPostion = position;
    });
    // return await Geolocator.getCurrentPosition();
  }

  late int datetime;

  void _getCurrentTime() async {
    setState(() {
      datetime = DateTime.now().toUtc().millisecondsSinceEpoch;
    });
  }

  void myPost() async {
    _getCurrentTime();
    _getUserLocation();
    print(currentPostion.latitude);
    print(currentPostion.longitude);
    print(datetime);
    final response = await api?.save(imageName, imagebytes);
    print(response?.downloadLink);
    try {
      var postResponse = await Dio().post("https://btp-backend-1.el.r.appspot.com/api/v1/posts/createPost",
      data: {
        "description": descController.text.toString(),
        "imgLink": response?.downloadLink.toString(),
        "unixTime": datetime,
        "longitude": currentPostion.longitude,
        "latitude": currentPostion.latitude
      });
      print(postResponse.statusCode);
      print(postResponse.data.toString());
    } catch (e) {
      print(e);
    }
    showDialog(
      context: context,
      builder: (context) {
        Future.delayed(Duration(seconds: 5), () {
          Navigator.of(context).pop(true);
        });
        return AlertDialog(
          title: Text('Image Posted'),
        );
      });
  }

  void getPost() async {
    var getResponse = await Dio().get("https://btp-backend-1.el.r.appspot.com/api/v1/posts");
    print(getResponse.statusCode);
    // final body = (getResponse.data as List).map((e) => OnBoardingModel);
    // for(var temp in getResponse.data)
    //   print(temp["imgLink"]);
    // print(getResponse.data[14]["longitude"]);
    var date = DateTime.fromMillisecondsSinceEpoch(getResponse.data[13]["unixTime"]);
    print(date);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          elevation: 16,
          child: Container(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                SizedBox(height: 20),
                Center(child: Text('Posts')),
                SizedBox(height: 20),
                for(var post in getResponse.data)
                _buildRow(post["imgLink"].toString(), post["description"].toString(), post["latitude"], post["longitude"], DateTime.fromMillisecondsSinceEpoch(post["unixTime"]).toString())
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildRow(String imageLink, String desc, double lat, double lon, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: <Widget>[
          SizedBox(height: 12),
          Container(height: 2, color: Colors.redAccent),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageLink,
                //to show image, you type like this.
                // Image.network(imageLink),
                fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width,
                height: 300,
              ),
            ),
          ),
          Text("Description: $desc"),
          Text("Date and Time: $date"),
          Text("Latitude: "'$lat'),
          Text("Longitude: "'$lon'),
          // Row(
          //   children: <Widget>[
          //     CircleAvatar(child: Image.network(imageLink)),
          //     SizedBox(width: 12),
          //     Text(desc),
          //     Spacer(),
          //     Container(
          //       decoration: BoxDecoration(color: Colors.yellow[900], borderRadius: BorderRadius.circular(20)),
          //       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          //       child: Text(date),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  TextEditingController descController = new TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Image'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  myAlert();
                },
                child: Text('Upload Photo'),
              ),
              SizedBox(
                height: 10,
              ),
              //if image not null show the image
              //if image null show text
              image != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          //to show image, you type like this.
                          File(image!.path),
                          fit: BoxFit.cover,
                          width: MediaQuery.of(context).size.width,
                          height: 300,
                        ),
                      ),
                    )
                  : Text(
                      "No Image",
                      style: TextStyle(fontSize: 20),
                    ),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter a description',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  myPost();
                },
                child: Text('Post'),
              ),
              ElevatedButton(
                onPressed: () {
                  getPost();
                },
                child: Text('Get all posts'),
              ),

              // Image.network('https://storage.googleapis.com/download/storage/v1/b/post-images-btp-backend/o/image_picker1489233255569740349.jpg?generation=1675701216300036&alt=media'),
            ],
          ),
        ),
      ),
    );
  }
}
