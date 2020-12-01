import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:location/location.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'FlutterBase',
        home: Scaffold(
        body: FireMap()));
  }
}

class FireMap extends StatefulWidget {
  @override
  State createState() => FireMapState();
}

class FireMapState extends State<FireMap> {
  GoogleMapController mapController;
  Firestore firestore = Firestore.instance;
  Geoflutterfire geo = Geoflutterfire();
  Location location = new Location();

  // Stateful data
  BehaviorSubject<double> radius = BehaviorSubject(seedValue: 100.0);
  Stream<dynamic> query;
  StreamSubscription subscription;


  void _onMapCreated(GoogleMapController controller) {
     _startQuery();
    setState(() {
      mapController = controller;
    });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

  void _animateToUser(LatLng target) {
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          bearing: 270.0,
          target: target,
          zoom: 17.0,
        )
      )
    );
  }

  _startQuery() async {
    // Get users location
    var pos = await location.getLocation();
    double lat = pos['latitude'];
    double lng = pos['longitude'];

    _animateToUser(LatLng(lat, lng));

    // Make a referece to firestore
    var ref = firestore.collection('locations');
    GeoFirePoint center = geo.point(latitude: lat, longitude: lng);

    // query = geo.collection(collectionRef: ref).within(center: center, radius: 1.0, field: 'position');
    // subscription = query.listen((List<DocumentSnapshot> snap) {
    //   _updateMarkers(snap);
    // });

    subscription = radius.switchMap((r) {
      return geo.collection(collectionRef: ref).within(center: center, radius: r, field: 'position');
    }).listen((snap) {

      int len = snap.length;

      print('found $len points');
      _updateMarkers(snap);
    });
  }

  /// Adds a GeoPoint to the database
  Future<DocumentReference> _addGeoPoint() async {
    var loc = await location.getLocation();
    return firestore.collection('locations').add({ 
      'position': geo.point(latitude: loc['latitude'], longitude: loc['longitude']).data,
      'name': 'Howdy' 
    });
  }

  build(context) {
    return Stack(
      children: [
        Container(
            width: MediaQuery.of(context).size.width,
            child: GoogleMap(
              myLocationEnabled: true,
              trackCameraPosition: true,
              mapType: MapType.terrain,
              onMapCreated: _onMapCreated,
              initialCameraPosition:
                  CameraPosition(target: LatLng(24.150, -74), zoom: 10),
            )),
        Positioned(
            bottom: 50,
            right: 10,
            child: FlatButton(
                child: Icon(
                  FontAwesomeIcons.thumbtack,
                  color: Colors.green[200],
                ),
                color: Colors.green,
                onPressed: () => _addGeoPoint())
        ), 
        Positioned(
          bottom: 50,
          left: 10,
          child: _buildSlider()
        )
      ],
    );
  }



void _addMarker(double lat, double lng, distance) {
    var _marker = MarkerOptions(
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindowText: InfoWindowText('Magic Marker', '🍄🍄🍄 $distance kilometers from query center')
    );
    mapController.addMarker(_marker);
  }

  void _updateMarkers(List<DocumentSnapshot> documentList) {
      mapController.clearMarkers();
       documentList.forEach((DocumentSnapshot document) {
         GeoPoint point = document.data['position']['geopoint'];
         double distance = document.data['distance'];
         _addMarker(point.latitude, point.longitude, distance);
       });
     }
   

  _buildSlider() {
    return Slider(
      min: 100.0,
      max: 500.0,
      divisions: 4,
      value: radius.value,
      label: 'Radius ${radius.value}km',
      activeColor: Colors.green,
      inactiveColor: Colors.green.withOpacity(0.2),
      onChanged: (v) => _updateQuery(v),
    );
  }

  final zoomMap = {
    100.0: 12.0,
    200.0: 10.0,
    300.0: 7.0,
    400.0: 6.0,
    500.0: 5.0 
  };

  _updateQuery(value) {
    final zoom = zoomMap[value];
      setState(() {
        radius.add(value);
        mapController.moveCamera(CameraUpdate.zoomTo(zoom));
      });
    }

    
}

