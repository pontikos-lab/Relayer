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
/** global: Plotly */
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
                allowedExtensions: ['jpeg', 'jpg', 'tif', 'h5'],
                itemLimit: 500,
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
            if (RL.checkFileNames) {
                console.log('Filenames Validated');
            } else {
                console.log('Filenames Not Validated');
            }
            var formData = $("#oct_segmentation_analysis").serializeArray();
            formData.push({
                name: "files",
                value: JSON.stringify(RL.fineUploader.getUploads())
            });
            $.ajax({
                url: '/oct_segmentation',
                type: 'post',
                data: formData,
                dataType: "json",
                success: function(data) {
                    $('#loading_modal').modal('close');
                    $('#analysis_results').show();
                    console.log(data);
                    RL.produceResults(data);
                    $("html, body").animate({
                        scrollTop: $('#analysis_results').offset().top
                    });
                },
                error: function(xhr) {
                    $('#loading_modal').modal('close');
                    console.log(xhr);
                }
            });
        });
    };

    RL.checkFileNames = function() {
        var files = RL.fineUploader.getUploads();
        console.log(files);
        if (files.length > 1) {
            var filenameEndings = RL.getFilenamesEndings;
            var sorted = RL.isSorted(filenameEndings);
            console.log(sorted);
        }
        return true;
    };

    RL.getFilenamesEndings = function() {
        var filenames = [];
        for (var i = 0; i < files.length; i++) {
            var e = parseInt(files[i].originalName.slice(-3));
            filenames.push(e);
        }
        return filenames;
    };

    RL.isSorted = function(a) {
        for (var i = 0; i < a.length; i++) {
            if (a[i] > a[i + 1]) {
                return false; // It is proven that the array is not sorted.
            }
        }
        return true; // If this part has been reached, the array must be sorted.
    };

    RL.produceResults = function(data) {
        $("#analysis_results").data("uuid", data.uniq_run);
        jsonFile = "Relayer/users/Relayer/" + data.uniq_run + "/out/thickness.json";

        $.getJSON(jsonFile, function(json) {
            RL.initSlider(json.length);
            RL.surfacePlot = RL.create3dSurfacePlot(json, data.scale);
            window.addEventListener("resize", function() {
                Plotly.Plots.resize(RL.surfacePlot);
            });
            RL.setImage(1);
        });
    };

    RL.create3dSurfacePlot = function(z_data, colourScale) {
        console.log(colourScale);
        var data = [{ z: z_data, type: "surface", colorscale: colourScale }];
        var layout = { title: "Thickness (µm)", scene: { zaxis: { range: [0, 600] } } };
        var parentWidth = 100;
        var surfacePlotNode = Plotly.d3
            .select("#surface_plot")
            .style({
                width: parentWidth + "%",
                "margin-left": (100 - parentWidth) / 2 + "%"
            });
        var surfacePlot = surfacePlotNode.node();
        Plotly.newPlot(surfacePlot, data, layout);

        surfacePlot.on("plotly_hover", function(data) {
            var debounced_fn = _.debounce(function() {
                var infotext = data.points.map(function(d) {
                    if (d.y !== 0) {
                        var slider = document.getElementById("segmented_image_slider");
                        slider.noUiSlider.set(d.y);
                    }
                });
            }, 50);
            debounced_fn();
        });
        return surfacePlot;
    };

    RL.setImage = function(i) {
        var uuid = $("#analysis_results").data('uuid');
        var url = "/Relayer/users/Relayer/" + uuid + "/out/" + RL.lpad(i) + ".jpg";
        $("#segmented_image").attr('src', url);
    };

    // Left Pad a number
    RL.lpad = function(value) {
        var padding = 3;
        var zeroes = new Array(padding + 1).join("0");
        return (zeroes + value).slice(-padding);
    };

    RL.initSlider = function(y_max) {
        var slider = document.getElementById("segmented_image_slider");
        noUiSlider.create(slider, {
            start: 1,
            step: 1,
            orientation: "horizontal", // 'horizontal' or 'vertical'
            range: {
                min: 1,
                max: y_max
            },
            format: {
                to: function(val) {
                    return RL.round(val, 0);
                },
                from: function(val) {
                    return RL.round(val, 0);
                }
            }
        });
        slider.noUiSlider.on("update", function(values, handle) {
            var debounced_fn = _.debounce(function() {
                var val = values[handle];
                RL.setImage(val);
                $("#segmented_image_number").text(val);
            }, 50);
            debounced_fn();
        });
    };

    RL.showExemplarResults = function() {
        $("#analysis_results").show();
        data = {
            uniq_run: "2017-12-01_16-19-01_558-558259000",
            scale: [
                ["0", "rgb(52,0,230)"],
                ["0.25", "rgb(0,56,199)"],
                ["0.5", "rgb(0,207,48)"],
                ["0.75", "rgb(85,255,0)"],
                ["1", "rgb(214,255,0)"]
            ],
            exit_code: 0
        };
        RL.produceResults(data);
    };

    RL.initExemplarResultsBtn = function() {
        $(".exemplar_output").on('click', function(e) {
            $("#beta_modal").modal('close');
            RL.showExemplarResults();
        });
    };

    RL.setupGoogleAuthentication = function() {
        gapi.auth.authorize({
            immediate: true,
            response_type: "code",
            cookie_policy: "single_host_origin",
            client_id: RL.CLIENT_ID,
            scope: "email"
        });
        $(".login_button").on("click", function(e) {
            e.preventDefault();
            /** global: gapi */
            gapi.auth.authorize({
                    immediate: false,
                    response_type: "code",
                    cookie_policy: "single_host_origin",
                    client_id: RL.CLIENT_ID,
                    scope: "email"
                },
                function(response) {
                    if (response && !response.error) {
                        // google authentication succeed, now post data to server.
                        jQuery.ajax({
                            type: "POST",
                            url: "/auth/google_oauth2/callback",
                            data: response,
                            success: function() {
                                // TODO - just update the DOM instead of a redirect
                                $(location).attr(
                                    "href",
                                    RL.protocol() + window.location.host + "/oct_segmentation"
                                );
                            }
                        });
                    } else {
                        console.log("ERROR Response google authentication failed");
                        // TODO: ERROR Response google authentication failed
                    }
                }
            );
        });
    };

    RL.protocol = function() {
        if (RL.USING_SLL === "true") {
            return "https://";
        } else {
            return "http://";
        }
    };

    RL.addUserDropDown = function() {
        $(".dropdown-button").dropdown({
            inDuration: 300,
            outDuration: 225,
            hover: true,
            belowOrigin: true,
            alignment: "right"
        });
    };

    RL.round = function(value, decimals) {
        return Number(Math.round(value + 'e' + decimals) + 'e-' + decimals);
    };
}());

(function($) {
    $(function() {
        $('.modal').modal();
        $('#loading_modal').modal({ dismissible: false });
        $("select").material_select();
        $(".button-collapse").sideNav();
        RL.initExemplarResultsBtn();
        RL.addUserDropDown();
        RL.initSubmit();
        RL.initFineUploader();
    });

    $(function() {
        return $.ajax({
            url: "https://apis.google.com/js/client:plus.js?onload=gpAsyncInit",
            dataType: "script",
            cache: true
        });
    });

    window.gpAsyncInit = function() {
        RL.setupGoogleAuthentication();
    };
})(jQuery);