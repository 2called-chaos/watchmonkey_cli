# Watchmonkey CLI

Watchmonkey is a very simple tool to monitor resources with Ruby without the need of installing agents on the systems you want to monitor. To accomplish this the application polls information via SSH or other endpoints (e.g. websites, FTP access). It's suitable for small to medium amounts of services.

Before looking any further you might want to know:

  * There is no escalation or notification system but you may add it yourself
  * I created this for being used with [Platypus](http://sveinbjorn.org/platypus) hence the [Platypus Hook](https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/platypus.rb)
  * This is how the text output looks like: [Screenshot](http://imgur.com/8yLYnKb)
  * This is how the Platypus support looks like: [ProgressBar](http://imgur.com/Vd8ZD7A) [HTML/WebView](http://imgur.com/5FwmWFZ)

---

## Help
If you need help or have problems [open an issue](https://github.com/2called-chaos/watchmonkey_cli/issues/new).


## Features
  * Monitor external resources (Web, FTP, Server health via SSH)
  * Run once or loop forever with ReQueue (define intervals globally, per checker or per single test)
  * Includes a selection of buildin checkers (basic *nix health, WWW availability & SSL expiration, FTP)


## Requirements
  * Ruby >= 2.0
  * Unixoid OS (such as Ubuntu/Debian, OS X, maybe others) or Windows (not recommended)
  * something you want to monitor


## Installation
  * `gem install watchmonkey_cli`
  * `watchmonkey --generate-config [name=default]`
  * Edit the created file to fit your needs
  * Run `watchmonkey`
  * Check out the additional features below (e.g. ReQueue)


## Usage
To get a list of available options invoke Watchmonkey with the `--help` or `-h` option:

    Usage: watchmonkey [options]
    # Application options
            --generate-config [myconfig] Generates a example config in ~/.watchmonkey
        -l, --log [file]                 Log to file, defaults to ~/.watchmonkey/logs/watchmonkey.log
        -t, --threads [NUM]              Amount of threads to be used for checking (default: 10)
        -s, --silent                     Only print errors and infos
        -q, --quiet                      Only print errors

    # General options
        -d, --debug [lvl=1]              Enable debug output
        -m, --monochrome                 Don't colorize output
        -h, --help                       Shows this help
        -v, --version                    Shows version and other info
        -z                               Do not check for updates on GitHub (with -v/--version)
            --dump-core                  for developers


## Documentation
Writing a documentation takes time and I'm not sure if anyone is even interested in this tool. If there is interest I will write a documentation but for now this Readme must suffice. If you need help just [open an issue](https://github.com/2called-chaos/watchmonkey_cli/issues/new) :)


## Create configs
Use the `--generate-config` option or refer to the [configuration template](https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/application/configuration.tpl) for examples and documentation.


## Deactivate configs
If you want to deactivate single configs just rename the file to start with two underscores (e.g.: `__example.rb`).


## Application configuration
If you want to add custom checkers, hooks or change default settings you can create `~/.watchmonkey/config.rb`. The file will be eval'd in the application object's context. Take a look at the [example configuration file](https://github.com/2called-chaos/watchmonkey_cli/blob/master/doc/config_example.rb) and [application.rb](https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/application.rb).


## Custom checkers
If you want to monitor something that is not covered by the buildin handlers you can create your own, it's not that hard and should be a breeze if you are used to Ruby. All descendants of the `WatchmonkeyCli::Checker` class will be initialized and are usable in the application. Documentation is thin but you can take a look at the [example checker](https://github.com/2called-chaos/watchmonkey_cli/blob/master/doc/checker_example.rb), the [buildin checkers](https://github.com/2called-chaos/watchmonkey_cli/tree/master/lib/watchmonkey_cli/checkers) or just [open an issue](https://github.com/2called-chaos/watchmonkey_cli/issues/new) and I might just implement it real quick.


## Additional Features

### ReQueue
By default Watchmonkey will run all tests once and then exit. This addon will enable Watchmonkey to run in a loop and run tests on a periodic interval.
Since this seems like a core feature it might get included directly into Watchmonkey but for now take a look at the documentation in the [ReQueue source code](https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/requeue.rb) for integration instructions.

### Platypus support
[Platypus](http://sveinbjorn.org/platypus) is a MacOS software to create dead simple GUI wrappers for scripts. There is buildin support for the interface types ProgressBar and WebView. For information look at the documentation in the [Platypus hook source code](https://github.com/2called-chaos/watchmonkey_cli/blob/master/lib/watchmonkey_cli/hooks/platypus.rb).


## Contributing
  Contributions are very welcome! Either report errors, bugs and propose features or directly submit code:

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Added some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request


## Legal
* © 2016, Sven Pachnit (www.bmonkeys.net)
* watchmonkey_cli is licensed under the MIT license.
