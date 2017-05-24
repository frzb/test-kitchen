# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Author:: Gunter Miegel (<gunter.miegel@rgsqd.de>)
#
# Copyright (C) 2013, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/provisioner/chef_base"

module Kitchen
  module Provisioner
    # Chef Client provisioner.
    #
    # @author Fletcher Nichol <fnichol@nichol.ca>
    class ChefClient < ChefBase
      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      default_config :client_rb, {}
      default_config :named_run_list, {}
      default_config :json_attributes, true

      default_config :chef_client_path do |provisioner|
        provisioner
          .remote_path_join(%W{#{provisioner[:chef_omnibus_root]} bin chef-client})
          .tap { |path| path.concat(".bat") if provisioner.windows_os? }
      end

      # (see Base#create_sandbox)
      def create_sandbox
        super
        prepare_validation_pem
        prepare_client_key_pem
        prepare_config_rb
      end

      # (see Base#prepare_command)
      def prepare_command
        config_filepath = remote_path_join(config[:root_path], config_filename)
        # Calling a shell and 'cd' before the upload looks nasty - but 'knife upload' refuses to work with an absolute
        # path.
        prepare_cmd = sudo("sh -c 'cd #{config[:root_path]} && knife upload * --config #{config_filepath}'")
        #debug("Prepare command to be run: #{prepare_cmd}")
        return prepare_cmd
      end

      # (see Base#run_command)
      def run_command
        cmd = sudo(config[:chef_client_path])
        debug("Command to be run: #{cmd}")

        chef_cmd(cmd)
      end

      private

      # Adds optional flags to a chef-client command, depending on
      # configuration data. Note that this method mutates the incoming Array.
      #
      # @param args [Array<String>] array of flags
      # @api private
      def add_optional_chef_client_args!(args)
        if config[:json_attributes]
          json = remote_path_join(config[:root_path], "dna.json")
          args << "--json-attributes #{json}"
        end
        args << "--logfile #{config[:log_file]}" if config[:log_file]
        args << "--profile-ruby" if config[:profile_ruby]
      end


      # Returns an Array of command line arguments for the chef client.
      #
      # @return [Array<String>] an array of command line arguments
      # @api private
      def chef_args(client_rb_filename)
        level = config[:log_level]
        args = [
          "--config #{remote_path_join(config[:root_path], client_rb_filename)}",
          "--log_level #{level}",
          "--force-formatter",
          "--no-color",
        ]
        add_optional_chef_client_args!(args)

        args
      end

      # Writes a fake (but valid) validation.pem into the sandbox directory.
      #
      # @api private
      def prepare_validation_pem
        info("Preparing validation.pem")
        debug("Using a dummy validation.pem")

        source = File.join(File.dirname(__FILE__),
                           %w{.. .. .. support dummy-validation.pem})
        FileUtils.cp(source, File.join(sandbox_path, "validation.pem"))
      end

      # Writes a fake (but valid) client.pem into the sandbox directory.
      # TODO: Find out how the client_key is generated by the chef-zero provisioner.
      # Currently we just copy the same fake key as for validation form the support directory.
      # @api private
      def prepare_client_key_pem
        info("Preparing client.pem")
        debug("Using a dummy client.pem")

        source = File.join(File.dirname(__FILE__),
                           %w{.. .. .. support dummy-validation.pem})
        FileUtils.cp(source, File.join(sandbox_path, "client.pem"))
      end
    end
  end
end
