// ignore_for_file: deprecated_member_use

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
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'api.dart';
import 'login_screen.dart';
import 'package:dotted_border/dotted_border.dart';
import 'NetworkHandler.dart';

void main() => runApp(MaterialApp(
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    ));

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int pageIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      pageIndex = index;
    });
  }

  final pages = [
    Page1(),
    Page2(),
    // Page3(),
    Icon(
      Icons.map_outlined,
      size: 150,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Road Reporter",
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: pages[pageIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add_a_photo_rounded),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_headline_rounded),
            label: 'Posts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
        ],
        currentIndex: pageIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class Page1 extends StatefulWidget {
  @override
  _Page1State createState() => _Page1State();
}

class _Page1State extends State<Page1> {
  File? image;
  late Uint8List imagebytes;
  late String imageName;
  PickedFile? _pickedFile;
  CloudApi? api;
  final ImagePicker _picker = ImagePicker();
  late Position currentPostion;
  late int datetime;
  TextEditingController descController = TextEditingController();
  Map<String, int> categories = {};
  String category = "";
  List<String> prediction = [];
  final networkHandler = NetworkHandler();
  TextEditingController catController = TextEditingController();

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/credentials.json').then((json) {
      api = CloudApi(json);
    });
  }

  //we can upload image from camera or from gallery based on parameter
  Future _pickImage(ImageSource media) async {
    var temp = await networkHandler.get("/predict/ping");
    _pickedFile = await _picker.getImage(source: media
        // maxHeight: 100,
        // maxWidth: 100
        );

    setState(() {
      image = File(_pickedFile!.path);
      imagebytes = image!.readAsBytesSync();
      imageName = image!.path.split('/').last;
    });

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(image!.path, filename: imageName),
    });
    var predict = await networkHandler.predict(formData);
    prediction.clear();
    for (var value in predict.data["prediction"])
      prediction.add(value.toString());
    print(prediction);
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

  void selectmore(BuildContext context) async {
    var getCategories = await networkHandler.get("/category/allCategories");
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                title: Text('Select a category', textAlign: TextAlign.center),
                content: SingleChildScrollView(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (var trait in getCategories.data["list"])
                      if (trait["isTrained"] == false)
                        InkWell(
                            onTap: () {
                              setState(() {
                                category = trait["categoryName"].toString();
                              });
                            },
                            child: Container(
                              height: 40,
                              color: category != ""
                                  ? category == trait["categoryName"].toString()
                                      ? Colors.grey
                                      : Colors.white
                                  : Colors.white,
                              child: Center(
                                  child: Text(
                                trait["categoryName"].toString(),
                                style: TextStyle(fontSize: 18),
                              )),
                            )),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      child: SizedBox(
                          height: 40.0,
                          child: TextField(
                            controller: catController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'If none please specify',
                            ),
                          )),
                    ),
                    TextButton(
                        child: const Text("Ok"),
                        onPressed: () {
                          if (catController.text != '')
                            setState(() {
                              category = catController.text.toString();
                            });
                          Navigator.of(context, rootNavigator: true).pop();
                        }),
                  ],
                )),
              );
            },
          );
        });
  }

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

  void _getCurrentTime() async {
    setState(() {
      datetime = DateTime.now().toUtc().millisecondsSinceEpoch;
    });
  }

  void samplePost() async {
    var test = await networkHandler.get("/post/ping");
    print(test.data);
    test.data == "OK" ? print("fine") : print("not fine");
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(image!.path, filename: imageName),
    });
    var predict = await networkHandler.predict(formData);
    print(image!.path);
    print(predict.data["prediction"]);
    print(predict.data["prediction"][0]);
    print(predict.data["prediction"][0]);
    _getCurrentTime();
    _getUserLocation();
    var data = {
      "description": descController.text.toString(),
      "unixTime": datetime,
      // "longitude": currentPostion.longitude,
      // "latitude": currentPostion.latitude,
      "classId": predict.data["prediction"][0][0],
      "className": predict.data["prediction"][0][1].toString()
    };
    print(json.encode(data));
    print(category);
    var getCategories = await networkHandler.get("/category/allCategories");
    for (var cat in getCategories.data["list"]) {
      categories[cat["categoryName"]] = cat["id"];
    }
    if (!categories.containsKey(category)) {
      var data = {"categoryName": category.toString()};
      var createResponse =
          await networkHandler.post("/category/createCategory", data);
    }
    getCategories = await networkHandler.get("/category/allCategories");
    categories.clear();
    for (var cat in getCategories.data["list"]) {
      categories[cat["categoryName"]] = cat["id"];
    }
    print(categories[category]);
  }

  void myPost() async {
    showDialog(
        context: context,
        builder: (context) {
          Future.delayed(Duration(seconds: 5), () {
            Navigator.of(context).pop(true);
          });
          return AlertDialog(
            title: Text('Posting Image'),
          );
        });
    _getCurrentTime();
    _getUserLocation();
    print(currentPostion.latitude);
    print(currentPostion.longitude);
    print(datetime);
    final response = await api?.save(imageName, imagebytes);
    print(response?.downloadLink);
    var test = await networkHandler.get("/predict/ping");
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(image!.path, filename: imageName),
    });
    var predict = await networkHandler.predict(formData);
    var getCategories = await networkHandler.get("/category/allCategories");
    for (var cat in getCategories.data["list"]) {
      categories[cat["categoryName"]] = cat["id"];
    }
    if (!categories.containsKey(category)) {
      var data = {"categoryName": category.toString()};
      var createResponse =
          await networkHandler.post("/category/createCategory", data);
    }
    getCategories = await networkHandler.get("/category/allCategories");
    categories.clear();
    for (var cat in getCategories.data["list"]) {
      categories[cat["categoryName"]] = cat["id"];
    }
    print(categories[category]);
    if (test.data == "OK") {
      if (predict.data["prediction"] != null) {
        try {
          var data = {
            "description": descController.text.toString(),
            "imgLink": response?.downloadLink.toString(),
            "unixTime": datetime/1000.round(),
            "longitude": currentPostion.longitude,
            "latitude": currentPostion.latitude,
            "categoryId" : categories[category]
          };
          var postResponse =
              await networkHandler.post("/post/createPost", data);
          print(postResponse.statusCode);
          print(postResponse.data.toString());
        } catch (e) {
          print(e);
        }
      } else {
        showDialog(
            context: context,
            builder: (context) {
              Future.delayed(Duration(seconds: 5), () {
                Navigator.of(context).pop(true);
              });
              return AlertDialog(
                title: Text('Predictor returned null'),
              );
            });
      }
    } else {
      showDialog(
          context: context,
          builder: (context) {
            Future.delayed(Duration(seconds: 5), () {
              Navigator.of(context).pop(true);
            });
            return AlertDialog(
              title: Text('Predictor is not working'),
            );
          });
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

  Future<List<String>> _getprediction() async {
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(image!.path, filename: imageName),
    });
    var predict = await networkHandler.predict(formData);
    prediction.clear();
    for (var value in predict.data["prediction"])
      prediction.add(value.toString());
    return prediction;
  }

  // ignore: prefer_final_fields
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Image'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DottedBorder(
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  // padding: EdgeInsets.all(6),
                  color: Colors.black,
                  strokeWidth: 2,
                  child: SizedBox(
                    height: 320,
                    width: 320,
                    child: image == null
                        ? IconButton(
                            icon: const Icon(Icons.add_a_photo_rounded),
                            onPressed: () {
                              myAlert();
                            })
                        : Stack(
                            children: <Widget>[
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    //to show image, you type like this.
                                    File(image!.path),
                                    width: 640,
                                    height: 640,
                                    // fit: BoxFit.cover,
                                  )),
                              Positioned(
                                  right: -9,
                                  top: -9,
                                  child: IconButton(
                                      icon: Icon(
                                        Icons.cancel,
                                        color: Colors.black,
                                        size: 30,
                                      ),
                                      onPressed: () => setState(() {
                                            image = null;
                                          })))
                            ],
                          ),
                  )),
              // ElevatedButton(
              //   onPressed: () {
              //     myAlert();
              //   },
              //   child: Text('Upload Photo'),
              // ),
              // SizedBox(
              //   height: 10,
              // ),
              // //if image not null show the image
              // //if image null show text
              // image != null
              //     ? Padding(
              //         padding: const EdgeInsets.symmetric(horizontal: 20),
              //         child: ClipRRect(
              //           borderRadius: BorderRadius.circular(8),
              //           child: Image.file(
              //             //to show image, you type like this.
              //             File(image!.path),
              //             fit: BoxFit.cover,
              //             // width: MediaQuery.of(context).size.width,
              //             // height: 300,
              //           ),
              //         ),
              //       )
              //     : Text(
              //         "No Image",
              //         style: TextStyle(fontSize: 20),
              //       ),
              // SizedBox(height: 12),
              // FutureBuilder(
              //     future: _getprediction(),
              //     builder: (BuildContext context, AsyncSnapshot snapshot) {
              //       if (!snapshot.data) {
              //         return SizedBox(height: 0);
              //       } else {
              //         final prediction = snapshot.data;
              //         return Container(
              //             decoration: BoxDecoration(
              //                 border: Border.all(),
              //                 borderRadius:
              //                     BorderRadius.all(Radius.circular(5))),
              //             margin: const EdgeInsets.symmetric(
              //                 vertical: 12.0, horizontal: 20),
              //             height: 50.0,
              //             child: ListView(
              //               scrollDirection: Axis.horizontal,
              //               children: <Widget>[
              //                 for (var trait in prediction)
              //                   InkWell(
              //                       onTap: () {
              //                         setState(() {
              //                           category = trait.toString();
              //                         });
              //                       },
              //                       child: Container(
              //                         //         decoration: BoxDecoration(
              //                         // border: Border(right: BorderSide())),
              //                         width: 150,
              //                         color: category != ""
              //                             ? category == trait
              //                                 ? Colors.grey
              //                                 : Colors.white
              //                             : Colors.white,
              //                         child: Center(
              //                             child: Text(
              //                           trait.toString(),
              //                           style: TextStyle(fontSize: 18),
              //                         )),
              //                       )),
              //                 InkWell(
              //                     onTap: () {
              //                       setState(() {
              //                         category = "";
              //                       });
              //                       selectmore(context);
              //                     },
              //                     child: Container(
              //                       width: 200,
              //                       // color: Colors.purple[600],
              //                       child: Center(
              //                           child: Text(
              //                         "Select from more",
              //                         style: TextStyle(fontSize: 18),
              //                       )),
              //                     )),
              //               ],
              //             ));
              //       }
              //     }),
              image != null
                  ? Container(
                      decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.all(Radius.circular(5))),
                      margin: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 20),
                      height: 50.0,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          for (var trait in prediction)
                            InkWell(
                                onTap: () {
                                  setState(() {
                                    category = trait.toString();
                                  });
                                },
                                child: Container(
                                  //         decoration: BoxDecoration(
                                  // border: Border(right: BorderSide())),
                                  width: 150,
                                  color: category != ""
                                      ? category == trait
                                          ? Colors.grey
                                          : Colors.white
                                      : Colors.white,
                                  child: Center(
                                      child: Text(
                                    trait.toString(),
                                    style: TextStyle(fontSize: 18),
                                  )),
                                )),
                          InkWell(
                              onTap: () {
                                setState(() {
                                  category = "";
                                });
                                selectmore(context);
                              },
                              child: Container(
                                width: 200,
                                // color: Colors.purple[600],
                                child: Center(
                                    child: Text(
                                  "Select from more",
                                  style: TextStyle(fontSize: 18),
                                )),
                              )),
                        ],
                      ))
                  : SizedBox(height: 20),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter a description',
                    ),
                  )),
              ElevatedButton(
                onPressed: () {
                  myPost();
                },
                child: Text('Post'),
              ),
              ElevatedButton(
                onPressed: () {
                  samplePost();
                },
                child: Text('Sample Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Page2 extends StatefulWidget {
  @override
  _Page2State createState() => _Page2State();
}

class _Page2State extends State<Page2> {
  // final loginApi = LoginApi();
  final networkHandler = NetworkHandler();
  Future<Response> _getData() async {
    var getResponse = await networkHandler.get("/post/allPosts");
    print(getResponse.data);
    return getResponse;
  }

  @override
  void initState() {
    super.initState();
  }

  static Future<void> navigateTo(double latitude, double longitude) async {
    String googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    await launch(googleUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("All Posts"),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: _getData(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (!snapshot.hasData) {
            // while data is loading:
            return Center(
              child: CircularProgressIndicator(),
            );
          } else {
            // data loaded:
            final getResponse = snapshot.data;
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (var post in getResponse.data["list"])
                      _buildRow(
                          post["imgLink"].toString(),
                          post["description"].toString(),
                          post["latitude"],
                          post["longitude"],
                          DateTime.fromMillisecondsSinceEpoch(post["unixTime"]*1000)
                              .toString(),
                          post["categoryName"].toString(),
                          post["email"].toString()
                          )
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRow(
      String imageLink, String desc, double lat, double lon, String date, String categoryName, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: <Widget>[
          SizedBox(height: 12),
          Container(height: 2, color: Theme.of(context).primaryColor),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageLink,
                //to show image, you type like this.
                fit: BoxFit.cover,
                // width: MediaQuery.of(context).size.width,
                // height: 300,
              ),
            ),
          ),
          Text("Description: $desc"),
          Text("Date and Time: $date"),
          Text("Latitude: " '$lat'),
          Text("Longitude: " '$lon'),
          Text("Class: $categoryName"),
          Text("Added by: $email"),
          TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 20),
            ),
            onPressed: () {
              navigateTo(lat, lon);
            },
            child: const Text('View on map'),
          ),
        ],
      ),
    );
  }
}
