$(document).on("click", ".add", function () {
  // 選択された親要素をコピーし、親要素の後に追加する ※親要素は<div id="item">になる
  $(this).prev().clone(true).insertAfter($(this).prev());
});
// －ボタン(class="del")がクリックされたら
$(document).on("click", ".del", function () {
  // 2ヵ所で使うので選択された親要素を変数targetに格納 ※親要素は<div id="item">になる
  var target = $(this).parent();
  // targetの親要素の配下の要素数が1以下だったら ※targetの親要素は<div id="list">になる
  if(target.parent().children().length > 1){
    // <div id="item">を削除する
    target.remove();
  }
});