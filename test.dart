import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:you_app/models/chat/message_model.dart';
import 'package:you_app/models/nearby_places_response_model.dart';
import 'package:you_app/screen/components/appbar/custom_appbar_general.dart';
import 'package:you_app/screen/components/base_page.dart';
import 'package:you_app/screen/components/gap_platform.dart';
import 'package:you_app/screen/components/text/text_widget.dart';
import 'package:you_app/screen/page/chat/widgets/location/suggestion.dart';
import 'package:you_app/services/navigation.dart';
import 'package:you_app/services/permission_handler.dart';
import 'package:you_app/utils/alert_toast.dart';
import 'package:you_app/utils/app_assets.dart';
import 'package:you_app/utils/string.dart';
import 'package:you_app/utils/themes.dart';

import '../../../../components/custom_button/gradient_button.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({Key? key}) : super(key: key);

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? googleMapController;

  static const CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(37.42796133580664, -122.085749655962), zoom: 14);

  Set<Marker> markers = {};

  List<Suggestion> suggestionAutoComplete = List<Suggestion>.empty();
  Place? place;

  String apiKey = mapsKey;
  String radius = "30";

  Position? curretPosition;
  CameraPosition? cameraPosition;

  double latitude = 31.5111093;
  double longitude = 74.279664;
  bool isHasAccess = false;
  bool isLoading = false;

  NearbyPlacesResponse nearbyPlacesResponse = NearbyPlacesResponse();

  checkPermissionLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      curretPosition = await determinePosition();
      // setCurrentLocation();
      setState(() {
        isHasAccess = true;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error $e");
      setState(() {
        isHasAccess = false;
        isLoading = false;
      });
    }
  }

  setCurrentLocation() {
    // Position position = await determinePosition();

    googleMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            curretPosition?.latitude ?? latitude,
            curretPosition?.longitude ?? longitude,
          ),
          zoom: 14,
        ),
      ),
    );

    latitude = curretPosition?.latitude ?? latitude;
    longitude = curretPosition?.longitude ?? longitude;
    place = null;

    setState(() {});
  }

  Future<List<Suggestion>> fetchSuggestions(String input) async {
    final Dio dio = GetIt.I<Dio>();
    final request =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?location=$latitude,$longitude&radius=1000&input=$input&key=$apiKey';
    // 'https://maps.googleapis.com/maps/api/place/autocomplete/json?location=$latitude,$longitude&radius=1000&input=$input&types=address&key=$apiKey';
    final response = await dio.get(request);

    if (response.statusCode == 200) {
      final result = response.data;
      if (result['status'] == 'OK') {
        // compose suggestions in a list
        var data = result['predictions']
            .map<Suggestion>((p) => Suggestion(p['place_id'], p['description']))
            .toList();
        setState(() {
          suggestionAutoComplete = data;
        });
        return data;
      }
      if (result['status'] == 'ZERO_RESULTS') {
        setState(() {
          suggestionAutoComplete = [];
        });
        return [];
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  Future<String?> getPlaceIdFromLatLng(double lat, double lng) async {
    final Dio dio = GetIt.I<Dio>();
    final request =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';
    final response = await dio.get(request);

    if (response.statusCode == 200) {
      final result = response.data;
      if (result['status'] == 'OK') {
        var placeId = result['results'][0]['place_id'];
        return placeId;
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  Future<Place?> getPlaceDetailFromId(String placeId) async {
    final Dio dio = GetIt.I<Dio>();
    final request =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';
    final response = await dio.get(request);

    if (response.statusCode == 200) {
      final result = response.data;
      if (result['status'] == 'OK') {
        final place = Place();
        final location = result['result']['geometry']['location'];
        place.latitude = location['lat'];
        place.longitude = location['lng'];
        place.name = result['result']['name'];
        place.street = result['result']['formatted_address'];
        return place;
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  void getNearbyPlaces() async {
    final Dio dio = GetIt.I<Dio>();
    var url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&key=$apiKey';

    var response = await dio.post(url);

    log('resp ${response.data}');
    nearbyPlacesResponse = NearbyPlacesResponse.fromJson(response.data);

    setState(() {});
  }

  Future<void> submitAutoComplete(String placeId) async {
    place = await getPlaceDetailFromId(placeId);

    if (place != null) {
      googleMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              latitude = place?.latitude ?? latitude,
              longitude = place?.longitude ?? longitude,
            ),
            zoom: 14,
          ),
        ),
      );
    }
  }

  updateMarkers() {
    markers.clear();

    markers.add(
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: LatLng(
          latitude = place?.latitude ?? latitude,
          longitude = place?.longitude ?? longitude,
        ),
      ),
    );
  }

  onCameraIdle() async {
    var placeId = await getPlaceIdFromLatLng(
      cameraPosition?.target.latitude ?? latitude,
      cameraPosition?.target.longitude ?? longitude,
    );
    if (placeId != null) {
      place = await getPlaceDetailFromId(placeId);
      // updateMarkers();
      getNearbyPlaces();
      setState(() {});
    }
  }

  submit() {
    if (place != null) {
      sendLocation(
        place?.latitude,
        place?.longitude,
        place?.name,
        place?.street,
      );
    } else {
      showToastError(errorMsg);
    }
  }

  @override
  void initState() {
    super.initState();
    checkPermissionLocation();
  }

  sendLocation(lat, long, name, street) async {
    var location = MessageLocation(
        latitude: lat, longitude: long, name: name, street: street);

    GetIt.I<NavigationServiceMain>().pop(location);
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      appBar: const CustomAppBarGeneral(label: "send_location"),
      resizeToAvoidBottomInset: false,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : !isHasAccess
              ? TextWidget(
                  text: locationDeniedPermanently,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w600,
                ).px20().centered()
              : VStack(
                  [
                    Autocomplete<Suggestion>(
                      displayStringForOption: (option) =>
                          option.description ?? '',
                      fieldViewBuilder: (context, textEditingController,
                          focusNode, onFieldSubmitted) {
                        return TextFormField(
                          focusNode: focusNode,
                          controller: textEditingController,
                          onChanged: (value) {
                            if (value.length >= 2) {
                              fetchSuggestions(value);
                            }
                          },
                          onFieldSubmitted: (value) {
                            // if (formkey.currentState!.validate()) {
                            //   textEditingController.clear();
                            // }
                          },
                          validator: (value) {
                            return value!.isEmpty
                                ? "cant_be_empty".tr()
                                : value.length < 2
                                    ? '${"minimum".tr()} ${2} ${"character".tr()}'
                                    : value.length > 45
                                        ? '${"maximum".tr()} ${45} ${"character".tr()}'
                                        : null;
                          },
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(45),
                          ],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: inputbg,
                            border: const OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: SvgPicture.asset(
                              AppIcons.search,
                              color: Colors.white,
                              fit: BoxFit.scaleDown,
                            ),
                            hintText: "search".tr(),
                          ),
                        ).py8().px16();
                      },
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.length < 2) {
                          return const Iterable<Suggestion>.empty();
                        }
                        return suggestionAutoComplete.map((Suggestion option) {
                          return option;
                        });
                      },
                      onSelected: (Suggestion selection) {
                        FocusScope.of(context).unfocus();
                        debugPrint(
                            'You just selected ${selection.description}');
                        submitAutoComplete(selection.placeId ?? '');
                      },
                    ),
                    Gap(4.sp),
                    Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: initialCameraPosition,
                          markers: markers,
                          zoomControlsEnabled: false,
                          mapType: MapType.normal,
                          onMapCreated: (GoogleMapController controller) {
                            googleMapController = controller;
                            setCurrentLocation();
                          },
                          onCameraMove: (position) {
                            place = null;
                            cameraPosition = position;
                            latitude = position.target.latitude;
                            longitude = position.target.longitude;
                            setState(() {});
                          },
                          onCameraIdle: onCameraIdle,
                        ).px8().h32(context),
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(1, 2),
                                    color: Colors.grey.shade400,
                                  )
                                ],
                                size: 50,
                              ),
                              const SizedBox(height: 40)
                            ],
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: setCurrentLocation,
                      child: HStack(
                        [
                          const TextWidget(
                              text: "navigate", fontWeight: FontWeight.w600),
                          Gap(5.sp),
                          Image.asset(
                            AppIcons.navigation,
                            width: 20.sp,
                            height: 20.sp,
                          ),
                        ],
                      ).objectCenterRight().p8().onTap(setCurrentLocation),
                    ),
                    Gap(8.sp),
                    Expanded(
                      child: SingleChildScrollView(
                        child: VStack(
                          [
                            // buildMenuAttachment(
                            //   icon: AppIcons.routing,
                            //   labelMenu: "share_live_location",
                            //   onPressed: () {},
                            // ),
                            // Gap(8.sp),
                            buildMenuAttachment(
                              icon: AppIcons.gps,
                              labelMenu: "share_current_location",
                              onPressed: () async {
                                // Position position = await determinePosition();
                                List<Placemark> placemarks =
                                    await placemarkFromCoordinates(
                                  curretPosition?.latitude ?? latitude,
                                  curretPosition?.longitude ?? latitude,
                                );

                                if (placemarks.isNotEmpty) {
                                  sendLocation(
                                    curretPosition?.latitude ?? latitude,
                                    curretPosition?.longitude ?? longitude,
                                    placemarks[0].name,
                                    placemarks[0].street,
                                  );
                                } else {
                                  showToastError(errorMsg);
                                }
                              },
                            ),
                            Gap(16.sp),
                            const TextWidget(
                              text: "send_other_location",
                              fontWeight: FontWeight.w600,
                            ).px20(),
                            Gap(4.sp),
                            if (nearbyPlacesResponse.results != null)
                              for (int i = 0;
                                  i < nearbyPlacesResponse.results!.length;
                                  i++)
                                nearbyPlacesWidget(
                                  icon: AppIcons.location,
                                  map: nearbyPlacesResponse.results![i],
                                ),
                            Gap(8.sp),
                          ],
                        ),
                      ),
                    ),
                    GradientButton(
                      onTap: submit,
                      title: "send_location",
                      colors: place != null ? gradientFincy : isFill,
                      gradientColors: place != null ? isFillGradient : aintFill,
                    ).h(50.sp).px16(),
                    const GapPlatform()
                  ],
                ),
    );
  }

  Widget nearbyPlacesWidget(
      {required Results map, required String icon, Function()? onPressed}) {
    return HStack(
      [
        Image.asset(
          icon,
          width: 24.sp,
          height: 24.sp,
        )
            .box
            .rounded
            .p8
            .color(CustomColor.inverseSurface.withOpacity(0.5))
            .make(),
        Gap(10.sp),
        VStack(
          [
            ValueTextWidget(
              text: map.name ?? "",
              fontWeight: FontWeight.w500,
              fontSize: 13.sp,
              overflow: TextOverflow.ellipsis,
            ).objectCenterLeft().expand(),
            map.vicinity != null
                ? ValueTextWidget(
                    text: map.vicinity ?? "",
                    fontWeight: FontWeight.w500,
                    fontSize: 13.sp,
                    overflow: TextOverflow.ellipsis,
                  ).expand()
                : Container(),
          ],
        ).expand()
      ],
    )
        .px20()
        .py8()
        .wFull(context)
        .box
        .color(CustomColor.inverseSurface.withOpacity(0.0))
        .make()
        .wFull(context)
        .h(50.sp)
        .onTap(() {
      sendLocation(map.geometry?.location?.lat, map.geometry?.location?.lng,
          map.name, map.vicinity);
    });
  }

  Widget buildMenuAttachment(
      {required String labelMenu,
      required String icon,
      Function()? onPressed}) {
    return HStack(
      [
        Image.asset(
          icon,
          width: 24.sp,
          height: 24.sp,
        )
            .box
            .rounded
            .p8
            .color(CustomColor.inverseSurface.withOpacity(0.5))
            .make(),
        Gap(10.sp),
        TextWidget(
          text: labelMenu,
          fontWeight: FontWeight.w500,
          fontSize: 13.sp,
        ).expand(),
      ],
    )
        .px20()
        .py8()
        .wFull(context)
        .box
        .color(CustomColor.inverseSurface.withOpacity(0.2))
        .make()
        .wFull(context)
        .h(50.sp)
        .onTap(onPressed);
  }
}
