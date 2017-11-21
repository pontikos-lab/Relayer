/*
    RL - Relayer's JavaScript module

    Define a global RL (acronym for Relayer) object containing all
    RL associated methods:
*/

// define global RL object
var RL;
if (!RL) {
    RL = {};
}

// RL module
(function() {
    RL.initFineUploader = function() {
        RL.fineUploader = new qq.FineUploader({
            element: $('#fine-uploader-validation')[0],
            template: 'qq-template-validation',
            request: {
                endpoint: '/upload'
            },
            thumbnails: {
                placeholders: {
                    waitingPath: '/assets/img/fine-uploader/placeholders/waiting-generic.png',
                    notAvailablePath: '/assets/img/fine-uploader/placeholders/not_available-generic.png'
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
        RL.fineUploader.addExtraDropzone($(".drop_zone_container")[0]);
    };

    RL.initSubmit = function() {
        $('#analysis_btn').on('click', function() {
            $('#loading_modal').modal('open');
            $('#modal_header_text').text('Running Analysis');
            $('#modal_text').text('This should take a few minutes. Please leave this page open');
            $.ajax({
                url: '/analyse',
                type: 'post',
                data: { 'files': RL.fineUploader.getUploads() },
                dataType: "json",
                success: function(data) {
                    $('#loading_modal').modal('close');
                    $('#analysis_results').show();
                    for (var i = 0; i < data.length; i++) {
                        RL.produceResults(data[i]);
                    }
                },
                error: function(xhr) {
                    $('#loading_modal').modal('close');
                    console.log(xhr);
                }
            });
        });
    };

    RL.produceResults = function(data) {
        jsonFile = 'Relayer/users/Relayer/' + data.run_dir +
            '/thickness.json';
        $.getJSON(jsonFile, function(json) {
            RL.surfacePlot = RL.create3dSurfacePlot(json);
            window.addEventListener('resize', function() {
                /** global: Plotly */
                Plotly.Plots.resize(RL.surfacePlot);
            });
        });
    };

    RL.create3dSurfacePlot = function(z_data) {
        var data = [{ z: z_data, type: 'surface' }];
        var layout = { title: 'Retinal Thickness' };
        var parentWidth = 100;
        var surfacePlotNode = Plotly.d3.select('#surface_plot')
            .style({
                width: parentWidth + '%',
                'margin-left': (100 - parentWidth) / 2 + '%'
            });
        var surfacePlot = surfacePlotNode.node();
        Plotly.newPlot(surfacePlot, data, layout);
        return surfacePlot;
    };
}());

(function($) {
    $(function() {
        RL.initFineUploader();
        RL.initSubmit();
        $('#loading_modal').modal({ dismissible: false });
    });
})(jQuery);