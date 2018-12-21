var stopnum = routes.length -1;
function initMap() {
  // ルート検索の条件
  var request = {
    origin: routes[0], // 出発地
    destination: routes[routes.length -1],// 目的地
    waypoints: [], //経由地
    travelMode: google.maps.DirectionsTravelMode.DRIVING, // 交通手段(歩行。DRIVINGの場合は車)
    // optimizeWaypoints: true,
  };
  for(var i=1;i<stopnum;i++){
    var locations = new Array();
    locations["location"] = routes[i]
    request['waypoints'].push(locations);
  }
    // マップの生成
  var map = new google.maps.Map(document.getElementById("map"), {
    center: new google.maps.LatLng(35.681382,139.766084), // マップの中心
  });
  var d = new google.maps.DirectionsService(); // ルート検索オブジェクト
  var r = new google.maps.DirectionsRenderer({ // ルート描画オブジェクト
    map: map, // 描画先の地図
    preserveViewport: false, // 描画後に中心点をずらす
  });
  // ルート検索
  d.route(request, function(result, status){
    // OKの場合ルート描画
    if (status == google.maps.DirectionsStatus.OK) {
      r.setDirections(result);
    }
  });
}
    
