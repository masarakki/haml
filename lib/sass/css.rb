require File.dirname(__FILE__) + '/../sass'
require 'sass/tree/node'
require 'strscan'

module Sass
  # :stopdoc:
  module Tree
    class Node
      def to_sass
        result = ''

        children.each do |child|
          result << "#{child.to_sass(0)}\n"
        end

        result
      end
    end

    class RuleNode
      def to_sass(tabs)
        str = "#{'  ' * tabs}#{rule}\n"

        children.each do |child|
          str << "#{child.to_sass(tabs + 1)}\n"
        end

        str
      end
    end

    class AttrNode
      def to_sass(tabs)
        "#{'  ' * tabs}:#{name} #{value}"
      end
    end
  end
  # :startdoc:

  # This class contains the functionality used in the +css2sass+ utility,
  # namely converting CSS documents to Sass templates.
  class CSS
    # :stopdoc:

    # The Regexp matching a CSS rule
    RULE_RE = /\s*([^\{]+)\s*\{/

    # The Regexp matching a CSS attribute
    ATTR_RE = /\s*[^::\{\}]+\s*:\s*[^:;\{\}]+\s*;/

    # :startdoc:

    # Creates a new instance of Sass::CSS that will compile the given document
    # to a Sass string when +render+ is called.
    def initialize(template)
      if template.is_a? IO
        template = template.read
      end

      @template = StringScanner.new(template)
    end

    # Processes the document and returns the result as a string
    # containing the CSS template.
    def render
      begin
        build_tree.to_sass
      rescue Exception => err
        line = @template.string[0...@template.pos].split("\n").size
        
        err.backtrace.unshift "(css):#{line}"
        raise err
      end
    end

    private

    def build_tree
      root = Tree::Node.new(nil)
      whitespace
      rules(root)
      root
    end

    def rules(root)
      rules = []
      while @template.scan(/[^\{\s]+/)
        rules << @template[0]
        whitespace

        if @template.scan(/\{/)
          result = Tree::RuleNode.new(rules.join(' '), nil)
          root << result
          rules = []

          whitespace
          attributes(result)
        end
      end
    end

    def attributes(rule)
      while @template.scan(/[^:\}\s]+/)
        name = @template[0]
        whitespace

        assert_match /:/
        
        value = ''
        while @template.scan(/[^;\s]+/)
          value << @template[0] << whitespace
        end
        
        assert_match /;/        
        rule << Tree::AttrNode.new(name, value, nil)
      end

      assert_match /\}/
    end

    def whitespace
      space = @template.scan(/\s*/) || ''

      # If we've hit a comment,
      # go past it and look for more whitespace
      if @template.scan(/\/\*/)
        @template.scan_until(/\*\//)
        return space + whitespace
      end
      return space
    end

    def assert_match(re)
      if !@template.scan(re)
        raise Exception.new("Invalid CSS!")
      end
      whitespace
    end
  end
end
