/*
 * CLLocation.j
 * CoreLocation
 *
 * Created by Nicholas Small.
 * Copyright 2010, 280 North, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import <Foundation/CPObject.j>

@import "MKReverseGeocoder.j"

CLLocationDidFindPlacemarkNotification = @"CLLocationDidFindPlacemarkNotification";

@implementation CLLocation : CPObject
{
    JSObject            coordinate  @accessors(readonly);
    CPDate              timestamp   @accessors(readonly);

    CLLocationAccuracy  accuracy    @accessors(readonly);

    MKPlacemark         placemark   @accessors;
    MKReverseGeocoder   _geocoder   @accessors(reaonly);
}

- (id)initWithLatitude:(float)latitude longitude:(float)longitude
{
    return [self initWithCoordinate:{latitude: latitude, longitude: longitude}
                    accuracy:(latitude && longitude ? 0 : -1)
                    timestamp:[CPDate date]];
}

- (id)initWithCoordinate:(JSObject)aCoordinate accuracy:(CLLocationAccuracy)anAccuracy timestamp:(CPDate)aDate
{
    self = [super init];

    if (self)
    {
        coordinate = aCoordinate;
        accuracy = anAccuracy;
        timestamp = aDate;
    }

    return self;
}

- (float)getDistanceFrom:(CLLocation)aLocation
{
	var coords1 = [self coordinate],
		coords2 = [aLocation coordinate],
	 	lat1 = coords1.latitude,
		lat2 = coords2.latitude,
		lng1 = coords1.longitude,
		lng2 = coords2.longitude;
	
    var R = 6371; // km
	var dLat = (lat2 - lat1).toRad();
	var dLon = (lng2 - lng1).toRad(); 
	var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
	        Math.cos(lat1.toRad()) * Math.cos(lat2.toRad()) * 
	        Math.sin(dLon/2) * Math.sin(dLon/2); 
	var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
	var d = R * c;
	return d;
}

- (BOOL)isInRegion:(MKCoordinateRegion)region {
	if([self latitude] < ([region.center latitude] - region.span.latitudeDelta / 2) || [self latitude] > ([region.center latitude] + region.span.latitudeDelta / 2) || [self longitude] < ([region.center longitude] - region.span.longitudeDelta / 2)  || [self longitude] > ([region.center longitude] + region.span.longitudeDelta / 2))
		return false;
	return true;
}

- (BOOL)isEqual:(CLLocation)rhs
{
    return coordinate.latitude === rhs.coordinate.latitude && coordinate.longitude === rhs.coordinate.longitude;
}

- (CPString)description
{
    return [CPString stringWithFormat:@"< %@, %@ > +/- %@ @ %@", coordinate.latitude, coordinate.longitude, accuracy, timestamp];
}

- (JSObject)latLng
{
    if (!coordinate)
        return nil;

    return new google.maps.LatLng(coordinate.latitude, coordinate.longitude);
}

- (void)setLatLng:(JSObject)aLatLngObject {
	coordinate.latitude = aLatLngObject.lat();
	coordinate.longitude = aLatLngObject.lng();
}

- (float)latitude {
	if(!coordinate)
		return 0;
	return coordinate.latitude;
}

- (float)longitude {
	if(!coordinate)
		return 0;
	return coordinate.longitude;
}

- (void)geocode
{
    if (_geocoder)
        [_geocoder cancel];

    _geocoder = [[MKReverseGeocoder alloc] initWithCoordinate:self];
    [_geocoder setDelegate:self];
    [_geocoder start];
}

- (void)reverseGeocoder:(MKReverseGeocoder)aCoder didFindPlacemark:(MKPlacemark)aPlacemark
{
    [self setPlacemark:aPlacemark];
    [[CPNotificationCenter defaultCenter] postNotificationName:CLLocationDidFindPlacemarkNotification object:self];
}

+ (float)convertGPSToFloat:(CPString)gps {
	var degrees = gps.replace(new RegExp("([0-9\\\.]*) deg ([0-9\\\.]*)'\\\ ([0-9\\\.]*)\\\"\ (.*)"),"$1;$2;$3;$4").split(";");
	var multi = 1.0;
	if (degrees[3] == "S" || degrees[3] == "W")
		multi = -1.0;
	return multi * (parseFloat(degrees[0]) + (parseFloat(degrees[1]) / 60) + (parseFloat(degrees[2]) / 3600));
}

@end


Number.prototype.toRad = function() {
	return this * Math.PI / 180;
}

function latLngBoundsToMKCoordinateRegion(region) {
	var center = [[CLLocation alloc] initWithLatitude:region.getCenter().lat() longitude:region.getCenter().lng()],
		lat = region.getNorthEast().lat() - region.getSouthWest().lat(),
		lng = region.getNorthEast().lng() - region.getSouthWest().lng();
	return {
		'center': center,
		'span' : {
			'latitudeDelta' : Math.abs(lat),
			'longitudeDelta' : Math.abs(lng)
		}
	};
};

function regionContainsRegion(region1,region2) {
	var rect1 = CPRectMake([region1.center latitude] - region1.span.latitudeDelta / 2,[region1.center longitude] - region1.span.longitudeDelta / 2,region1.span.latitudeDelta,region1.span.longitudeDelta),
		rect2 = CPRectMake([region2.center latitude] - region2.span.latitudeDelta / 2,[region2.center longitude] - region2.span.longitudeDelta / 2,region2.span.latitudeDelta,region2.span.longitudeDelta);
	return (rect2.origin.x >= rect1.origin.x && rect2.origin.x + rect2.size.width <= rect1.origin.x + rect1.size.width && rect2.origin.y >= rect1.origin.y && rect2.origin.y + rect2.size.height <= rect1.origin.y + rect1.size.height)
}