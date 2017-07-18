require "rexml/document"

class CheckstyleXmlReportGenerator
  attr_reader :data

  def initialize(data)
    @data = items_grouped_by_locations(data)
  end

  def render
    "".tap { |result| document.write(output: result, indent: 2) }
  end

  private

  def items_grouped_by_locations(data)
    data.each_with_object({}) do |item, object|
      item.locations.each do |location|
        file = location.file

        if object[file]
          object[file] << [location, item]
        else
          object[file] = [[location, item]]
        end
      end
    end
  end

  def document
    REXML::Document.new.tap do |document|
      document << REXML::XMLDecl.new << checkstyle
    end
  end

  def checkstyle
    REXML::Element.new('checkstyle').tap do |checkstyle|
      data.each do |filename, group|
        checkstyle << file(filename, group)
      end
    end
  end

  def file(filename, group)
    REXML::Element.new('file').tap do |file|
      file.add_attribute 'name', File.realpath(filename)

      group.each do |location, item|
        file << error(item, location)
      end
    end
  end

  def error(item, location)
    REXML::Element.new('error').tap do |error|
      error.add_attributes 'column' => 0,
        'line'     => location.line,
        'message'  => "#{smell_message(item)} (#{smell_locations_string(item.locations)})",
        'severity' => 'warning',
        'source'   => item.identical? ? 'IdenticalCode' : 'SimilarCode'
    end
  end

  def smell_message(item)
    match = item.identical? ? "IDENTICAL" : "Similar"
    "%s code found in %p (mass%s = %d)" % [match, item.name, item.bonus, item.mass]
  end

  def smell_locations_string(locations)
    [locations.map { |location| "#{location.file}:#{location.line}" }].join(", ")
  end
end
