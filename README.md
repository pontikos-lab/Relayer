# OCT Segmentation



## Introduction

This tool is a web application that segments OCT Scans...




## Installation
Feel free to give us a shout on the github issues, if you would like more help than that below.

### Installation Requirements
* Ruby (>= 2.2.0)
  * Recommended to use [rvm](https://rvm.io/rvm/install) to install ruby
* Matlab (=2016a)
  * Installation from [here](https://google.co.uk)

### App Installation
Simply run the following command in the terminal.

```bash
# Clone the repository.
git clone https://github.com/IsmailM/oct_segmentation

# Move into oct_segmentation source directory.
cd oct_segmentation

# Build and install the latest version of the webapp.
rake install

# Start the web app
passenger start -p 9292 -e production --sticky-sessions -d
```

##### Running From Source (Not Recommended)
It is also possible to run from source. However, this is not recommended.

```bash
# After cloning the web app and moving into the source directory
# Install bundler
gem install bundler

# Use bundler to install dependencies
bundle install

# Optional: run tests and build the gem from source
bundle exec rake

# Run oct_segmentator
bundle exec passenger start -h
# note that `bundle exec` executes oct_segmentator in the context of the bundle

# Alternatively run oct_segmentation using the command line interface
bundle exec oct_segmentation -h
```




## Launch oct_segmentator

To configure and launch oct_segmentation, run the following from a command line from the oct_segmentator root folder.

```bash
bundle exec passenger start -h

```
That's it! Open http://localhost:9292/ and start using oct_segmentator!






## Advanced Usage

See `$ passenger start -h` for more information on all the options available when running oct_segmentator.

# Config file
A Config file can be used to specify arguments - the default location of this file is in the home directory at `~/.oct_segmentation.conf`. An examplar of the config file can be seen below.


```yaml
---
:num_threads: 8
:port: '9292'
:host: 0.0.0.0
:data_dir: "/Users/ismailm/.oct_segmentation"
:devel: true
```


<hr>
