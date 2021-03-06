# frozen_string_literal: true

require "dependabot/npm_and_yarn/file_updater/npmrc_builder"
require "dependabot/npm_and_yarn/file_updater/package_json_preparer"

module Dependabot
  module NpmAndYarn
    class UpdateChecker
      class DependencyFilesBuilder
        def initialize(dependency:, dependency_files:, credentials:)
          @dependency = dependency
          @dependency_files = dependency_files
          @credentials = credentials
        end

        def write_temporary_dependency_files
          write_lock_files

          File.write(".npmrc", npmrc_content)

          package_files.each do |file|
            path = file.name
            FileUtils.mkdir_p(Pathname.new(path).dirname)
            File.write(file.name, prepared_package_json_content(file))
          end
        end

        def package_locks
          @package_locks ||=
            dependency_files.
            select { |f| f.name.end_with?("package-lock.json") }
        end

        def yarn_locks
          @yarn_locks ||=
            dependency_files.
            select { |f| f.name.end_with?("yarn.lock") }
        end

        def shrinkwraps
          @shrinkwraps ||=
            dependency_files.
            select { |f| f.name.end_with?("npm-shrinkwrap.json") }
        end

        def lockfiles
          [*package_locks, *shrinkwraps, *yarn_locks]
        end

        def package_files
          @package_files ||=
            dependency_files.
            select { |f| f.name.end_with?("package.json") }
        end

        private

        attr_reader :dependency, :dependency_files, :credentials

        def write_lock_files
          yarn_locks.each do |f|
            FileUtils.mkdir_p(Pathname.new(f.name).dirname)
            File.write(f.name, prepared_yarn_lockfile_content(f.content))
          end

          [*package_locks, *shrinkwraps].each do |f|
            FileUtils.mkdir_p(Pathname.new(f.name).dirname)
            File.write(f.name, f.content)
          end
        end

        # Duplicated in NpmLockfileUpdater
        # Remove the dependency we want to update from the lockfile and let
        # yarn find the latest resolvable version and fix the lockfile
        def prepared_yarn_lockfile_content(content)
          content.gsub(/^#{Regexp.quote(dependency.name)}\@.*?\n\n/m, "")
        end

        def prepared_package_json_content(file)
          NpmAndYarn::FileUpdater::PackageJsonPreparer.new(
            package_json_content: file.content
          ).prepared_content
        end

        def npmrc_content
          NpmAndYarn::FileUpdater::NpmrcBuilder.new(
            credentials: credentials,
            dependency_files: dependency_files
          ).npmrc_content
        end
      end
    end
  end
end
