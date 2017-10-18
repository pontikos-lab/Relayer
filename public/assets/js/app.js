/*
    OS - OctSegmentation's JavaScript module

    Define a global OS (acronym for OctSegmentation) object containing all
    OS associated methods:
*/

// define global OS object
var OS;
if (!OS) {
  OS = {};
}

// OS module
(function() {
  OS.initFineUploader = function() {
    OS.fineUploader = new qq.FineUploader({
      element: $('#fine-uploader-validation')[0],
      template: 'qq-template-validation',
      request: {
        endpoint: '/upload'
      },
      thumbnails: {
        placeholders: {
          waitingPath: '/assets/css/fine-uploader/placeholders/waiting-generic.png',
          notAvailablePath: '/assets/css/fine-uploader/placeholders/not_available-generic.png'
        }
      },
      validation: {
        allowedExtensions: ['jpeg', 'jpg', 'h5'],
        itemLimit: 3,
        sizeLimit: 78650000 // 75MB
      },
      chunking: {
        enabled: true,
        concurrent: {
          enabled: true
        },
        success: {
          endpoint: "/upload_done"
        }
      }
    });
    // OS.fineUploader.addExtraDropzone($('.app')[0]);
  };

  OS.initSubmit = function() {
    $('#analysis_btn').on('click', function() {
      $('#loading_modal').modal('open');
      $('#modal_header_text').text('Running Analysis');
      $('#modal_text').text('This should take a few minutes. Please leave this page open');
      $.ajax({
        url: '/analyse',
        type: 'post',
        data: {'files': OS.fineUploader.getUploads()},
        dataType: "json",
        success: function(data) {
          $('#loading_modal').modal('close');
          $('#analysis_results').show();
          for (var i = 0; i < data.length; i++) {
            OS.produceResults(data[i]);
          }
        },
        error: function(xhr) {
          $('#loading_modal').modal('close');
          console.log(xhr);
        }
      });
    });
  };

  OS.produceResults = function(data) {
    jsonFile = 'OctSegmentation/users/OctSegmentation/'+ data.run_dir +
               '/thickness.json';
    $.getJSON(jsonFile, function(json) {
      OS.surfacePlot = OS.create3dSurfacePlot(json);
      window.addEventListener('resize', function() {
        /** global: Plotly */
        Plotly.Plots.resize(OS.surfacePlot);
      });
    });
  };

  OS.create3dSurfacePlot = function(z_data) {
    var data = [{z: z_data, type: 'surface'}];
    var layout = {title: 'OCT Segmentation'};
    var parentWidth = 100;
    var surfacePlotNode = Plotly.d3.select('#surface_plot')
                                .style({width: parentWidth + '%',
                                 'margin-left': (100 - parentWidth) / 2 + '%'});
    var surfacePlot = surfacePlotNode.node();
    Plotly.newPlot(surfacePlot, data, layout);
    return  surfacePlot;
  };
}());

(function($) {
  $(function() {
    OS.initFineUploader();
    OS.initSubmit();
    $('#loading_modal').modal({dismissible: false});
  });
})(jQuery);
