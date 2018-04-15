/*
# Code Review plugin for Redmine
# Copyright (C) 2009-2017  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

var topZindex = 1000;
var action_type = '';
var rev = '';
var rev_to = '';
var path = '';
var urlprefix = '';
var review_form_dialog = null;
var filenames = [];

var addReviewUrl = null;
var showReviewImageTag = null;
var showClosedReviewImageTag = null;

var ReviewCount = function(total, open, progress){
    this.total = total;
    this.open = open;
    this.closed = total - open;
    this.progress = progress
};

var CodeReview = function(id) {
    this.id = id;
    this.path = '';
    this.line = 0;
    this.url = '';
    this.is_closed = false;
};

var review_counts = new Array();
var code_reviews_map = new Array();
var code_reviews_dialog_map = new Array();

function UpdateRepositoryView(title) {
    var header = $("table.changesets thead tr:first");
    var th = $('<th></th>');
    th.html(title);
    header.append(th);
    $('tr.changeset td.id a:first-child').each(function(i){
        var revision = this.getAttribute("href");
        revision = revision.substr(revision.lastIndexOf("/") + 1);        
        var review = review_counts['revision_' + revision];
        var td = $('<td/>',{
            'class':'progress'
        });
        td.html(review.progress);
        $(this.parentNode.parentNode).append(td);
    });
    }
//add function $.down
if(! $.fn.down)
(function($) {
    $.fn.down = function() {
        var el = this[0] && this[0].firstChild;
        while (el && el.nodeType != 1)
            el = el.nextSibling;
        return $(el);
    };
})(jQuery);

function UpdateRevisionView() {
    $('li.change').each(function(){
        var li = $(this);
        if (li.hasClass('folder')) return;

        var a = li.down('a');
        if (a.size() == 0) return;
        var path = a.attr('href').replace(urlprefix, '').replace(/\?.*$/, '');

        var reviewlist = code_reviews_map[path];
        if (reviewlist == null) return;

        var ul = $('<ul></ul>');
        for (var j = 0; j < reviewlist.length; j++) {
            var review = reviewlist[j];
            var icon = review.is_closed? 'icon-closed-review': 'icon-review';
            var item = $('<li></li>', {
                'class': 'icon ' + icon + ' code_review_summary'
                });
            item.html(review.url);
            ul.append(item);
        }
        li.append(ul);
    });
}

function setAddReviewButton(addReviewUrl, image_tag, is_readonly, is_diff){
    var filetables = [];
    var j = 0;
    $('table').each(function(){
        if($(this).hasClass('filecontent')){
            filetables[j++] = this;
        }
    });
    j = 0;
    $('table.filecontent th.filename').each(function(){
        filenames[j] = $.trim($(this).text());
        j++;
    });

    var num = 0;
    if (is_diff) {
        num = 1;
    }
    var i, l, tl;
    for (i = 0, tl = filetables.length; i < tl; i++) {
        var table = filetables[i];
        var trs = table.getElementsByTagName('tr');

        for (j = 0,l = trs.length; j < l; j++) {
            var tr = trs[j];
            var ths = tr.getElementsByTagName('th');

            var th = ths[num];
            if (th == null) {
                continue;
            }

            var th_html = th.innerHTML;

            var line = th_html.match(/[0-9]+/);
            if (line == null) {
                continue;
            }
            line = line[0];

            var span_html = '<span white-space="nowrap" id="review_span_' + line + '_' + i + '">';

            if (!is_readonly) {
                span_html += image_tag;
            }
            span_html += '</span>';
            th.innerHTML = th_html + span_html;

            var img = th.getElementsByTagName('img')[0];
            if (img != null ) {
              img = $(img);
              img.data('line', line);
              img.data('fileIdx', i);
              img.click(clickPencil);
            }
        }
    }


}

function clickPencil(e)
{
    var img = $(e.target);
    var fileIdx = img.data('fileIdx');
    var data = { line: img.data('line'), file_count: fileIdx };

    if (window.path == null || window.path.length == 0) {
      data.path = encodeURIComponent(window.filenames[fileIdx]);
      data.diff_all = true;
    }
    $.get(window.addReviewUrl, data);
    e.preventDefault();
}

function setShowReviewButton(url, line, review_id, is_closed, file_count) {
    //alert('file_count = ' + file_count);
    var span = $('#review_span_' + line + '_' + file_count);
    if (span.size() == 0) {
        return;
    }
    var innerSpan = $('<span></span>',{id: 'review_' + review_id});
    span.append(innerSpan);
    innerSpan.html(is_closed ? showClosedReviewImageTag : showReviewImageTag);
    var div = $('<div></div>', {
        'class':'draggable',
        id: 'show_review_' + review_id
    });
    $('#code_review').append(div);
    innerSpan.down('img').click(function(e) { $.get(url); });
}

function popupReview(review_id, url) {
    var span   = $('#review_' + review_id); // span element of view review button
    var pos = span.offset();
    $('html,body').animate({ scrollTop: pos.top },
        {duration: 'fast',
        complete: function(){ $.get(url); }});
}

// unused
// function getReviewObjById(review_id) {
//     for (var reviewlist in code_reviews_map) {
//         for (var i = 0; i < reviewlist.length; i++) {
//             var review = reviewlist[i];
//             if (review.id == review_id) {
//                 return review;
//             }
//         }
//     }
//     return null;
// }

function hideForm() {
  if(window.review_form_dialog) {
    window.review_form_dialog.dialog('close');
    window.review_form_dialog = null;
    $('#review-form').html('');
  }
}

// unused
// function deleteReview(review_id) {
//     $('show_review_' + review_id).remove();
//     $('review_' + review_id).remove();
// }

function changeImage(review_id, is_closed) {
    var span = $('review_' + review_id);
    var new_image = null;
    var dummy = new Element('span');
    if (is_closed) {
        dummy.insert(showClosedReviewImageTag);
    }
    else {
        dummy.insert(showReviewImageTag);
    }
    new_image = dummy.down().getAttribute('src');
    //alert(new_image);
    span.down('img').setAttribute('src', new_image);

}

function make_addreview_link(project, link) {
    var alist = $('div.tabs ul li a#tab-entry');
    if (alist == null) {
        return;
    }
    var a = alist[0];
    var p = a.parentNode.parentNode;
    p.innerHTML = p.innerHTML + link;
}

function call_update_revisions(url) {
    var changeset_ids = '';
    var links = $$('table.changesets tbody tr.changeset td.id a');
    for (var i = 0; i < links.length; i++) {
        var link = links[i];
        var href = link.getAttribute('href');
        var id = href.replace(/^.*\/revisions\//, '');
        if (i > 0) {
            changeset_ids += ',';
        }
        changeset_ids += id;
    }
    new Ajax.Updater('code_review_revisions', url,
    {
        evalScripts:true,
        method:'get',
        parameters: 'changeset_ids=' + encodeURI(changeset_ids)
    });
}

$.fn.serialize2json = function()
{
   var o = {};
   var a = this.serializeArray();
   $.each(a, function() {
       if (o[this.name]) {
           if (!o[this.name].push) {
               o[this.name] = [o[this.name]];
           }
           o[this.name].push(this.value || '');
       } else {
           o[this.name] = this.value || '';
       }
   });
   return o;
};
