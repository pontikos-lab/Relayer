# ReLayer

## Introduction

ReLayer is a web application that segments OCT Scans...

## Installation

Feel free to give us a shout on the github issues, if you would like more help than that below.

### Installation Requirements

* Ruby (>= 2.2.0)
  * Recommended to use [rvm](https://rvm.io/rvm/install) to install ruby
* Matlab (=2017a)
  * Installation from [here](https://www.mathworks.com/products/matlab.html)
    * The location of the matlab binary is reqiured

### App Installation

Simply run the following command in the terminal.

```bash
# Clone the repository.
git clone https://github.com/IsmailM/Relayer

# Move into relayer source directory.
cd Relayer

# Initialize and update Submodule
git submodule update --init --recursive

# Install Bundler
gem install bundler

# Build and install the latest version of the webapp.
rake install

# Start the web app
relayer
```

#### Running From Source (Not Recommended)

It is also possible to run from source. However, this is not recommended.

```bash
# After cloning the web app and moving into the source directory
# Install bundler
gem install bundler

# Use bundler to install dependencies
bundle install

# Run relayer
bundle exec passenger start -h
# note that `bundle exec` executes relayer in the context of the bundle

# Alternatively run relayer using the command line interface
bundle exec relayer -h
```

## Launch relayer

To configure and launch relayer, run the following from a command line from the relayer root folder.

```bash
bundle exec passenger start -h
```

That's it! Open [http://localhost:3000/](http://localhost:3000/) and start using relayer!

## Advanced Usage

See `$ passenger start -h` for more information on all the options available when running relayer.

## Config file

A Config file can be used to specify arguments - the default location of this file is in the home directory at `~/.relayer.conf`. An examplar of the config file can be seen below.

```yaml
---
:num_threads: 8
:port: 3000
:host: 0.0.0.0
:relayer_dir: "/Users/ismailm/.relayer"
:ssl: false
:matlab_bin: "/Applications/MATLAB_R2017a.app/bin/matlab"
:oct_library_path: "/Volumes/Data/project/relayer/matlab"
```

A config file can be generated using the `-s` argument. The above exemplar config file was generated as follows:

```bash
relayer -s -m "/Applications/MATLAB_R2017a.app/bin/matlab" -o "/Volumes/Data/project/relayer/matlab" -n 8
```