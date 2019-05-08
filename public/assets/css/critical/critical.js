var critical = require("critical");

var dimensions = [{
        width: 320,
        height: 480
    },
    {
        width: 768,
        height: 1024
    },
    {
        width: 1280,
        height: 1024
    },
    {
        width: 2560,
        height: 1400
    }
];

// critical.generate({
//     src: "http://localhost:9292/",
//     dest: "public/assets/css/critical/home.min.css",
//     dimensions: dimensions,
//     ignore: [/url\(/, '@font-face', /print/],
//     minify: true
// });

critical.generate({
    src: "http://localhost:3000/oct_segmentation",
    dest: "public/assets/css/critical/app.min.css",
    dimensions: dimensions,
    ignore: [/url\(/, "@font-face", /print/],
    include: ["qq-uploader-selector", "drop_zone_container", "profile_img"],
    timeout: 300000,
    minify: true
});

critical.generate({
    src: "http://localhost:3000/result/cmVsYXllcg==/2017-12-11_22-00-28_161-161900000",
    dest: "public/assets/css/critical/single_results.min.css",
    dimensions: dimensions,
    ignore: [/url\(/, "@font-face", /print/],
    include: ["profile_img"],
    timeout: 300000,
    minify: true
});

critical.generate({
    src: "http://localhost:3000/my_results",
    dest: "public/assets/css/critical/my_results.min.css",
    dimensions: dimensions,
    ignore: [/url\(/, "@font-face", /print/],
    include: ["profile_img"],
    timeout: 300000,
    minify: true
});