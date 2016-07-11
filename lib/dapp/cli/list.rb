require 'mixlib/cli'

module Dapp
  class CLI
    class List < Base
      banner <<BANNER.freeze
Version: #{Dapp::VERSION}

Usage:
  dapp list [options] [PATTERN ...]

    PATTERN                     Applications to process [default: *].

Options:
BANNER

    end
  end
end