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
            // Manually check if the select is empty
            if ($('select[name="machine_type"]').val()) {
                $('.validation_text').text('Please select the a Machine Type above.');
                return false;
            }

            if (RL.fineUploader.getInProgress() !== 0) {
                $('.validation_text').text('Please wait until all the files have completely uploaded.');
                return false;
            }

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

    RL.initDownloadResultBtn = function() {
        $("#download-all-results").on("click", function() {
            $("#modal_header_text").text("Creating Download Link");
            $("#loading_modal").modal({ dismissible: false });
            $("#loading_modal").modal("open");
            $.fileDownload($(this).data("download"), {
                successCallback: function() {
                    $("#loading_modal").modal("close");
                },
                failCallback: function() {
                    $("#loading_modal").modal("close");
                }
            });
            $("#loading_modal").modal("close");
            return false; //this is critical to stop the click event which will trigger a normal file download!
        });
    };

    RL.delete_result = function() {
        $("#analysis_results").on("click", "#delete_results", function() {
            $("#delete_modal").modal("open");
            var resultId = $(this).closest(".card").data("uuid");
            $("#delete_modal").attr("data-uuid", resultId);
        });

        $(".delete-results").click(function() {
            $("#modal_header_text").text("Deleting Result");
            $("#loading_modal").modal({ dismissible: false });
            $("#loading_modal").modal("open");
            var uuid = $("#delete_modal").data("uuid");
            $.ajax({
                type: "POST",
                url: "/delete_result",
                data: { uuid: uuid },
                success: function() {
                    location.reload();
                },
                error: function(e, status) {
                    RL.ajaxError(e, status);
                }
            });
        });
    };

    RL.share_result = function() {
        $("#analysis_results").on("click", "#share_btn", function() {
            var share_link = $(this).closest(".card").data("share-link");
            $("#share_the_link_btn").show();
            $("#share_btn").hide();
            $("#share_link_input").val(share_link);
            $("#share_link_input").prop("readonly", true);
            $("#share_modal").modal("open");
            $("#share_modal").attr("data-share-link", share_link);
            $("#share_link_input").select();
            $.ajax({
                type: "POST",
                url: share_link,
                error: function(e, status) {
                    RL.ajaxError(e, status);
                }
            });
        });
        $("#analysis_results").on("click", "#share_the_link_btn", function() {
            var share_link = $(this).closest(".card").data("share-link");
            $("#share_link_input1").val(share_link);
            $("#share_link_input1").prop("readonly", true);
            $("#share_the_link_modal").modal("open");
            $("#share_the_link_modal").attr("data-share-link", share_link);
            $("#share_link_input1").select();
        });

        $(".share_link_input").focus(function() {
            $(this).select();
            // Work around Chrome's little problem
            $(this).mouseup(function() {
                // Prevent further mouseup intervention
                $(this).unbind("mouseup");
                return false;
            });
        });
    };

    RL.remove_share = function() {
        $(".remove_link").click(function() {
            var share_link = $(this).closest(".modal").data("share-link");
            var remove_link = share_link.replace(/\/sh\//, "/rm/");
            $("#share_the_link_btn").hide();
            $("#share_btn").show();
            $("#share_modal").modal("close");
            $("#share_the_link_modal").modal("close");
            $.ajax({
                type: "POST",
                url: remove_link,
                error: function(e, status) {
                    RL.ajaxError(e, status);
                }
            });
        });
    };

    RL.ajaxError = function(e, status) {
        var errorMessage;
        if (e.status == 500 || e.status == 400) {
            errorMessage = e.responseText;
            $("#analysis_results").show();
            $("#analysis_results").html(errorMessage);
            $("#loading_modal").modal("close"); // remove progress notification
        } else {
            errorMessage = e.responseText;
            $("#analysis_results").show();
            $("#analysis_results").html('<div class="card red lighten-2" role="alert"><div class="card-content white-text"><h3>Oops! Relayer went wonky!</h3><p style="font-size: 1.5rem"><strong>Apologies, there was an error with your request. Please try again.</strong></p><p>Error Message:' + errorMessage + " The server responded with the status code: " + String(e.status) + ". Please refresh the page and try again.</p><p>If the error persists, please contact the administrator.</p></div></div>");
            $("#loading_modal").modal("close"); // remove progress notification
        }
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
        $(".analyse_card").data("assets_path", data.assets_path);
        $(".analyse_card").data("result_uuid", data.uuid);
        $(".analyse_card").data("share-link", data.share_url);
        $("#open_in_new_btn").attr("href", data.results_url);
        var download_link = data.assets_path + "/relayer_results.zip";
        $("#download-all-results").data("download", download_link);
        RL.initDownloadResultBtn();
        var jsonFile = data.assets_path + "/out/thickness.json";
        $.getJSON(jsonFile, function(json) {
            RL.initSlider(json.length);
            RL.surfacePlot = RL.create3dSurfacePlot(json, data.scale);
            window.addEventListener("resize", function() {
                Plotly.Plots.resize(RL.surfacePlot);
            });
        });
        RL.setImage(1);
        RL.delete_result();
        RL.share_result();
        RL.remove_share();
    };

    RL.create3dSurfacePlot = function(z_data, colourScale) {
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
        var assets_path = $(".analyse_card").data("assets_path");
        var url = assets_path + "/out/" + RL.lpad(i) + ".jpg";
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
            orientation: "horizontal",
            range: { min: 1, max: y_max },
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

    RL.addUserDropDown = function() {
        $(".dropdown-button").dropdown({
            inDuration: 300,
            outDuration: 225,
            hover: true,
            belowOrigin: true,
            alignment: "right"
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

    RL.round = function(value, decimals) {
        return Number(Math.round(value + 'e' + decimals) + 'e-' + decimals);
    };

    RL.showExemplarResults = function() {
        $("#analysis_results").show();
        var data = {
            uuid: "2018-01-19_01-14-17_700-700588804",
            assets_path: "https://relayer.online/relayer/users/relayer/2018-01-19_01-14-17_700-700588804",
            share_url: "https://relayer.online/sh/cmVsYXllcg==/2018-01-19_01-14-17_700-700588804",
            results_url: "https://relayer.online/result/cmVsYXllcg==/2018-01-19_01-14-17_700-700588804",
            scale: [
                ["0", "rgb(140,0,186)"],
                ["0.25", "rgb(39,0,236)"],
                ["0.5", "rgb(0,104,151)"],
                ["0.75", "rgb(18,255,0)"],
                ["1", "rgb(170,255,0)"]
            ],
            exit_code: 0
        };
        RL.produceResults(data);
        $("#delete_results").hide();
        $("#share_the_link_btn").hide();
        $('#share_btn').hide();
        $("html, body").animate({
            scrollTop: $("#analysis_results").offset().top
        });

    };

    RL.initExemplarResultsBtn = function() {
        $(".exemplar_output").on("click", function(e) {
            $("#beta_modal").modal("close");
            $("#modal_header_text").text("Producing Exemplar Results");
            $("#loading_modal").modal("open");
            RL.showExemplarResults();
            $("#analysis_results").imagesLoaded().then(function() {
                $("#loading_modal").modal("close");
            });
        });
    };
}());

(function($) {
    // Fn to allow an event to fire after all images are loaded
    $.fn.imagesLoaded = function() {
        var $imgs = this.find('img[src!=""]');
        // if there's no images, just return an already resolved promise
        if (!$imgs.length) {
            return $.Deferred().resolve().promise();
        }

        // for each image, add a deferred object to the array which resolves
        // when the image is loaded (or if loading fails)
        var dfds = [];
        $imgs.each(function() {
            var dfd = $.Deferred();
            dfds.push(dfd);
            /** global: Image */
            var img = new Image();
            img.onload = function() {
                dfd.resolve();
            };
            img.onerror = function() {
                dfd.resolve();
            };
            img.src = this.src;
        });
        // return a master promise object which will resolve when all
        // the deferred objects have resolved
        // i.e. - when all the images are loaded
        return $.when.apply($, dfds);
    };

    $(function() {
        $(".modal").modal();
        $("select").material_select();
        $(".button-collapse").sideNav();
        RL.addUserDropDown();
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