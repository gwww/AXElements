require 'ax_elements/key_coder'

##
# Parses strings of human readable text into a series of events meant
# to be processed by {Accessibility::Core#post:to:}.
module Accessibility::Core
  class StringParser

    def self.regenerate_dynamic_mapping
      MAPPING.merge! KeyCodeGenerator.dynamic_mapping
    end

    ##
    # Map of characters to keycodes. The map is generated at boot time in
    # order to support multiple keyboard layouts.
    #
    # @return [Hash{String=>Fixnum}]
    MAPPING = {}

    ##
    # @note Static values come from `/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h`
    #
    # @return [Hash{String=>Fixnum}]
    ESCAPES = {
      "\n"              => 0x24,
      "\\ESCAPE"        => 0x35,
      "\\COMMAND"       => 0x37,
      "\\SHIFT"         => 0x38,
      "\\CAPS"          => 0x39,
      "\\OPTION"        => 0x3A,
      "\\CONTROL"       => 0x3B,
      "\\RSHIFT"        => 0x3C,
      "\\ROPTION"       => 0x3D,
      "\\RCONTROL"      => 0x3E,
      "\\FUNCTION"      => 0x3F,
      "\\VOLUP"         => 0x48,
      "\\VOLDOWN"       => 0x49,
      "\\MUTE"          => 0x4A,
      "\\F17"           => 0x40,
      "\\F18"           => 0x4F,
      "\\F19"           => 0x50,
      "\\F20"           => 0x5A,
      "\\F5"            => 0x60,
      "\\F6"            => 0x61,
      "\\F7"            => 0x62,
      "\\F3"            => 0x63,
      "\\F8"            => 0x64,
      "\\F9"            => 0x65,
      "\\F11"           => 0x67,
      "\\F13"           => 0x69,
      "\\F16"           => 0x6A,
      "\\F14"           => 0x6B,
      "\\F10"           => 0x6D,
      "\\F12"           => 0x6F,
      "\\F15"           => 0x71,
      "\\HELP"          => 0x72,
      "\\HOME"          => 0x73,
      "\\PAGEUP"        => 0x74,
      "\\DELETE"        => 0x75,
      "\\F4"            => 0x76,
      "\\END"           => 0x77,
      "\\F2"            => 0x78,
      "\\PAGEDOWN"      => 0x79,
      "\\F1"            => 0x7A,
      "\\<-"            => 0x7B,
      "\\LEFT"          => 0x7B,
      "\\->"            => 0x7C,
      "\\RIGHT"         => 0x7C,
      "\\DOWN"          => 0x7D,
      "\\UP"            => 0x7E,
      "\\KEYPAD0"       => 0x52,
      "\\KEYPAD1"       => 0x53,
      "\\KEYPAD2"       => 0x54,
      "\\KEYPAD3"       => 0x55,
      "\\KEYPAD4"       => 0x56,
      "\\KEYPAD5"       => 0x57,
      "\\KEYPAD6"       => 0x58,
      "\\KEYPAD7"       => 0x59,
      "\\KEYPAD8"       => 0x5B,
      "\\KEYPAD9"       => 0x5C,
      "\\KEYPADDecimal" => 0x41,
      "\\KEYPADMultiply"=> 0x43,
      "\\KEYPADPlus"    => 0x45,
      "\\KEYPADClear"   => 0x47,
      "\\KEYPADDivide"  => 0x4B,
      "\\KEYPADEnter"   => 0x4C,
      "\\KEYPADMinus"   => 0x4E,
      "\\KEYPADEquals"  => 0x51,
    }

    # @return [Hash{String=>Fixnum}]
    ALT = {
      '~' => '`',
      '!' => '1',
      '@' => '2',
      '#' => '3',
      '$' => '4',
      '%' => '5',
      '^' => '6',
      '&' => '7',
      '*' => '8',
      '(' => '9',
      ')' => '0',
      '{' => '[',
      '}' => ']',
      '?' => '/',
      '+' => '=',
      '|' => "\\",
      ':' => ';',
      '_' => '-',
      '"' => "'",
      '<' => ',',
      '>' => '.',
      'A' => 'a',
      'B' => 'b',
      'C' => 'c',
      'D' => 'd',
      'E' => 'e',
      'F' => 'f',
      'G' => 'g',
      'H' => 'h',
      'I' => 'i',
      'J' => 'j',
      'K' => 'k',
      'L' => 'l',
      'M' => 'm',
      'N' => 'n',
      'O' => 'o',
      'P' => 'p',
      'Q' => 'q',
      'R' => 'r',
      'S' => 's',
      'T' => 't',
      'U' => 'u',
      'V' => 'v',
      'W' => 'w',
      'X' => 'x',
      'Y' => 'y',
      'Z' => 'z'
    }

    ##
    # Parse a string into a list of keyboard events to be executed in
    # the given order.
    #
    # @param [String]
    # @return [Array<Array(Number,Boolean)>]
    def parse string
      chars  = string.split ::EMPTY_STRING
      events = []
      until chars.empty?
        char = chars.shift
        event = if ALT[char]
                  parse_alt char
                elsif char == "\\"
                  parse_custom chars.unshift char
                else
                  parse_dynamic char
                end
        events.concat event
      end
      events
    end


    private

    # @param [String]
    def parse_alt char
      code  = MAPPING[ALT[char]]
      [[56,true], [code,true], [code,false], [56,false]]
    end

    # @param [Array<String>]
    def parse_custom string
      sequence = ''
      while string
        case string.first
        when '+'
          raise NotImplementedError, 'Hotkeys is not finished yet'
        when ' ', nil
          code = ESCAPES[sequence]
          return [[code,true], [code,false]]
        else
          sequence << string.shift
        end
      end
      raise 'String parsing failed!'
    end

    # @param [String]
    def parse_dynamic char
      if code = MAPPING[char]
        [[code,true], [code,false]]
      else
        raise ArgumentError, "#{char} has no mapping, bail!"
      end
    end

  end
end

##
# @note This will only work if a run loop is runnig
#
# Register to be notified if the keyboard layout changes at runtime
NSDistributedNotificationCenter.defaultCenter.addObserver Accessibility::Core::StringParser,
                                                selector: 'regenerate_dynamic_mapping',
                                                    name: KTISNotifySelectedKeyboardInputSourceChanged,
                                                  object: nil

# Initialize the table
Accessibility::Core::StringParser.regenerate_dynamic_mapping