# frozen_string_literal: true

require "nokogiri"
require "dependabot/nuget/file_updater"

module Dependabot
  module Nuget
    class FileUpdater
      class CorextConfigDeclarationFinder
        DECLARATION_REGEX =
            %r{<package [^>]*?/>|
             <package [^>]*?[^/]>.*?</package>}mx.freeze

        attr_reader :dependency_name, :declaring_requirement,
                    :corext_config

        def initialize(dependency_name:, corext_config:,
                       declaring_requirement:)
          @dependency_name        = dependency_name
          @corext_config        = corext_config
          @declaring_requirement  = declaring_requirement

          if declaring_requirement[:file].split("/").last.
              casecmp("corext.config").zero?
            return
          end

          raise "Requirement not from corext.config!"
        end

        def declaration_strings
          @declaration_strings ||= fetch_declaration_strings
        end

        def declaration_nodes
          declaration_strings.map do |declaration_string|
            Nokogiri::XML(declaration_string)
          end
        end

        private

        def fetch_declaration_strings
          deep_find_declarations(corext_config.content).select do |nd|
            node = Nokogiri::XML(nd)
            node.remove_namespaces!
            node = node.at_xpath("/package")

            node_name = node.attribute("id")&.value&.strip ||
                node.at_xpath("./id")&.content&.strip
            next false unless node_name&.downcase == dependency_name&.downcase

            node_requirement = node.attribute("version")&.value&.strip ||
                node.at_xpath("./version")&.content&.strip
            node_requirement == declaring_requirement.fetch(:requirement)
          end
        end

        def deep_find_declarations(string)
          string.scan(DECLARATION_REGEX).flat_map do |matching_node|
            [matching_node, *deep_find_declarations(matching_node[0..-2])]
          end
        end
      end
    end
  end
end
