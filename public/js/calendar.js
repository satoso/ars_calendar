function ready() {
  $('#all-0').on('click', function(){ $('form [type="radio"]').val(["0"]);});
  $('#all-1').on('click', function(){ $('form [type="radio"]').val(["1"]);});
  $('#all-2').on('click', function(){ $('form [type="radio"]').val(["2"]);});
  $('#all-3').on('click', function(){ $('form [type="radio"]').val(["3"]);});
  $('#del-before-btn').on('click', function(){
    $('#del-before').css('display','none');
    $('#del-after').css('display','inline');
  });
  $('#del-cancel-btn').on('click', function(){
    $('#del-before').css('display','inline');
    $('#del-after').css('display','none');
  });
  $('.rbtn-container').on('click', function(){
    $(this).children('[type="radio"]').prop('checked',true);
  });
}

$(document).ready(ready);
$(document).on('page:load', ready);
