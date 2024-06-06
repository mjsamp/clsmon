'use strict';
angular.module('portalApp', ['ngRoute'])
.config(['$routeProvider', function ($routeProvider) {

    $routeProvider.when('/about', {
        controller: 'clusterController',
        templateUrl: '/about.html',
    }).when('/aix_cluster_5', {
        controller: 'clusterController',
        templateUrl: '/clsmon/aix_cluster_5.html',
    }).otherwise({ redirectTo: '/clusters.html' });

}]);

