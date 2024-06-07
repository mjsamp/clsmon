'use strict';
angular.module('portalApp')
.controller('clusterController', ['$scope','$http','$timeout' , function ($scope, $http, $timeout) {


  $scope.buttonarray = new Array();
  var tmpbtnsetuparray = new Array();
  $scope.bgcolor = "#161d26";
  $scope.bottom_bgcolor = "#161d26";
  $scope.fcolor = "white";
  $scope.home = "clusters";
  $scope.counter = 0;
  var buttoncount;
  $scope.btablestyle;
  var btn_per_row = 1;
  var btntablewidth;
  var browserwidth;
  var browserwidth_last = 0;
  var lastinrow = false;
  $scope.body = new Array();
  $scope.clusters = new Array();
  var html = "Welcome to PowerHA Remote Cluster Monitor!";
  var csv = "";
  $scope.refreshrate = 5;

  var csv2json = function csvToJSON(csv, callback) {
            var lines = csv.split("\n");
            var result = [];
            var headers = lines[0].split(",");
            for (var i = 1; i < lines.length - 1; i++) {
                var obj = {};
                var currentline = lines[i].split(",");
                for (var j = 0; j < headers.length; j++) {
                    obj[headers[j]] = currentline[j];
                }
                result.push(obj);
            }
            if (callback && (typeof callback === 'function')) {
                return callback(result);
            }
            //console.log(result);
            return result;
  }


      $scope.refresh = function() {
            $http.get('/clsmon/clusters.csv').then(function(response){
                //console.log(response.data);
                csv = response.data;
                //alert('post added');
            }, function(response){
                csv = response.data;
                //console.log(response.data);
                //alert('post not added');
            });
            
            $scope.clusters = csv2json(csv);
            $scope.draw($scope.home);
            $scope.init();
            //console.log("refresh");
      }

      $scope.draw = function(home) {
            $http.get('/clsmon/'+home+'.html').then(function(response){
                //console.log(response.data);
                html = response.data;
                //alert('post added');
            }, function(response){
                html = response.data;
                //console.log(response);
                //alert('post not added');
            });

        document.getElementById("container-frame").innerHTML= html;
        $scope.home = home;
        //console.log("draw: "+home);

      }

  $scope.init = function() {
        $scope.bgcolor = "#161d26";
        $scope.bottom_bgcolor = "#161d26";
        buttoncount = 1;
        //$scope.btablestyle = {'width':(window.innerWidth-80)+'px'};
        browserwidth = window.innerWidth - 45;
        console.log("browserwidth: "+browserwidth);
        btntablewidth = browserwidth * 1.8;//document.getElementById('button_table').clientWidth * 2;//browserwidth * 2;
        console.log("btntablewidth: "+btntablewidth);
        if (btntablewidth < 1) {btntablewidth = 1;}
        var rows = Math.floor(btntablewidth/browserwidth) + 1;
        console.log("rows: "+rows);
        btn_per_row = Math.floor($scope.clusters.length / rows);
        console.log("btn_per_row: "+btn_per_row);
  
         // Clear buttonarray
        while($scope.buttonarray.length > 0) {
          $scope.buttonarray.pop();
        }
     
      for (var b=0; b < $scope.clusters.length; b++) {

              if(buttoncount < btn_per_row) {
                tmpbtnsetuparray.push({value:$scope.clusters[b].nodes,label:$scope.clusters[b].cluster_name,substate:$scope.clusters[b].css});
                buttoncount++;
                lastinrow = false;
              }
              else {
                tmpbtnsetuparray.push({value:$scope.clusters[b].nodes,label:$scope.clusters[b].cluster_name,substate:$scope.clusters[b].css});
                $scope.buttonarray.push({items:tmpbtnsetuparray});
                buttoncount = 1;
                lastinrow = false;
                tmpbtnsetuparray = new Array();
              }
        
      }
      
      $scope.btnstyle = function (substate,label) {
        var styletext = {'text-align':'center','font-size':'0.9em','width':'8.5em','border-radius':'3px'};

        styletext.border = '0.25em solid gray';
        
                if (substate == "STABLE") {
                  styletext.backgroundColor = '#34ff34';
                  styletext.color = 'black';               
                }

                if (substate == "UNSTABLE") {
                  styletext.backgroundColor = 'yellow';
                  styletext.color = 'black';  
                }
                
                if (substate == "UNKNOWN" || substate == "DOWN" || substate == "ERROR" || substate == "RECONFIG") {
                  styletext.backgroundColor = 'red';
                  styletext.color = 'white';

                  styletext.border = '0.25em solid yellow';
                  $scope.bottom_bgcolor = 'red';
                  //$scope.bgcolor = 'red';
        
                }
        
        if (label == $scope.home) {
            styletext.border = '0.25em solid orange';
        }


        return styletext;
      }  
       setTimeout($scope.refresh, ($scope.refreshrate * 1000));  
  }
  
}]);
