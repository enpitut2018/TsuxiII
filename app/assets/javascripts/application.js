// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require turbolinks
//= require_tree .
//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require jquery
//= require jquery_ujs

$(function(){
    var idNo = 1;
    
    // 追加ボタン押下時イベント
    $('button#addButton').on('click',function(){
        $('div#templateForm')
            // コピー処理
            .clone(true)
            // 不要なID削除
            .removeAttr("id")
            // 非表示解除
            .removeClass("notDisp")
            // テキストボックスのID追加
            .find("input[name=templateTextbox]")
            .attr("id", "textbox_" + idNo)
            .end()
            // ボタンのID追加
            .find("button[name=templateButton]")
            .on('click',function(){alert($(this).attr('id'));})
            .attr("id", "button_" + idNo)
            .end()
            // 情報表示
            .find("span.dispInfo")
            .text("id[" + idNo + "] TextBox_ID[" + "textbox_" + idNo + "] Button_ID:[" + "button_" + idNo + "]")
            .end()
            // 追加処理
            .appendTo("div#displayArea");
  
        // ID番号加算
        idNo++;
    });
  
    // 削除ボタン押下時イベント
    $('button[name=removeButton]').on('click',function(){
        $(this).parent('div').remove();
    });
    
    // 削除ボタン押下時イベント
    $('button[name=removeButton]').on('click',function(){
        $(this).parent('div').remove();
    });
});