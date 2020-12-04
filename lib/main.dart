import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:location/location.dart';

import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
        body: FireMap(),
      )
    );
  }
}

class FireMap extends StatefulWidget {
  State createState() => FireMapState();
}


class FireMapState extends State<FireMap> {
  GoogleMapController mapController;
  Location location = new Location();

  Firestore firestore = Firestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  // Stateful Data
  BehaviorSubject<double> radius = BehaviorSubject(seedValue: 100.0);
  Stream<dynamic> query;

  // Subscription
  StreamSubscription subscription;

  build(context) {
    return Stack(children: [

    GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(24.142, -110.321),
            zoom: 15
          ),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          mapType: MapType.hybrid, 
          compassEnabled: true,
          trackCameraPosition: true,
      ),
     Positioned(
          bottom: 50,
          right: 10,
          child: 
          FlatButton(
            child: Icon(Icons.pin_drop, color: Colors.white),
            color: Colors.green,
            onPressed: _addGeoPoint
          )
      ),
      Positioned(
        bottom: 50,
        left: 10,
        child: Slider(
          min: 100.0,
          max: 500.0, 
          divisions: 4,
          value: radius.value,
          label: 'Radius ${radius.value}km',
          activeColor: Colors.green,
          inactiveColor: Colors.green.withOpacity(0.2),
          onChanged: _updateQuery,
        )
      )
    ]);
  }

  // Map Created Lifecycle Hook
  _onMapCreated(GoogleMapController controller) {
    _startQuery();
    setState(() {
      mapController = controller;
    });
  }

  _addMarker() {
    var marker = MarkerOptions(
      position: mapController.cameraPosition.target,
      icon: BitmapDescriptor.defaultMarker,
      infoWindowText: InfoWindowText('Magic Marker', '🍄🍄🍄')
    );

    mapController.addMarker(marker);
  }

  _animateToUser() async {
    var pos = await location.getLocation();
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(pos['latitude'], pos['longitude']),
          zoom: 17.0,
        )
      )
    );
  }

  // Set GeoLocation Data
  Future<DocumentReference> _addGeoPoint() async {
    var pos = await location.getLocation();
    GeoFirePoint point = geo.point(latitude: pos['latitude'], longitude: pos['longitude']);
    return firestore.collection('locations').add({ 
      'position': point.data,
      'name': 'Yay I can be queried!' 
    });
  }

  void _updateMarkers(List<DocumentSnapshot> documentList) {
    print(documentList);
    mapController.clearMarkers();
    documentList.forEach((DocumentSnapshot document) {
        GeoPoint pos = document.data['position']['geopoint'];
        double distance = document.data['distance'];
        var marker = MarkerOptions(
          position: LatLng(pos.latitude, pos.longitude),
          icon: BitmapDescriptor.defaultMarker,
          infoWindowText: InfoWindowText('Magic Marker', '$distance kilometers from query center')
        );


        mapController.addMarker(marker);
    });
  }

  _startQuery() async {
    // Get users location
    var pos = await location.getLocation();
    double lat = pos['latitude'];
    double lng = pos['longitude'];


    // Make a referece to firestore
    var ref = firestore.collection('locations');
    GeoFirePoint center = geo.point(latitude: lat, longitude: lng);

    // subscribe to query
    subscription = radius.switchMap((rad) {
      return geo.collection(collectionRef: ref).within(
        center: center, 
        radius: rad, 
        field: 'position', 
        strictMode: true
      );
    }).listen(_updateMarkers);
  }

  _updateQuery(value) {
      final zoomMap = {
          100.0: 12.0,
          200.0: 10.0,
          300.0: 7.0,
          400.0: 6.0,
          500.0: 5.0 
      };
      final zoom = zoomMap[value];
      mapController.moveCamera(CameraUpdate.zoomTo(zoom));

      setState(() {
        radius.add(value);
      });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }


}