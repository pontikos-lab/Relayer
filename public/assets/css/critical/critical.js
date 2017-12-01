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
    include: ["qq-uploader-selector", 'drop_zone_container'],
    timeout: 300000,
    minify: true
});