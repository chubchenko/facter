test_name "C100305: The Ruby fact should resolve as expected in AIO" do
  tag 'risk:high'

#
# This test is intended to ensure that the the ruby fact resolves
# as expected in AIO across supported platforms.
#
  skip_test "Ruby fact test is confined to AIO" if @options[:type] != 'aio'

  require 'json'
  require 'facter/acceptance/base_fact_utils'
  extend Facter::Acceptance::BaseFactUtils

  agents.each do |agent|
    step "Ensure the Ruby fact resolves as expected" do
      puppet_version = on(agent, puppet("--version")).stdout.chomp
      ruby_version   = if puppet_version =~ /^(6|7)\./
                         /2\.\d+\.\d+/
                       else
                         /3\.\d+\.\d+/
                       end

      case agent['platform']
        when /windows/
          ruby_platform = agent['ruby_arch'] == 'x64' ? 'x64-mingw32' : 'i386-mingw32'
        when /osx/
          if agent['platform'] =~ /arm64/
            if puppet_version =~ /^(6|7)\./ && agent['platform'].split('-')[1].to_i < 13
              ruby_platform = /aarch64-darwin/
            else
              ruby_platform = /arm64-darwin/
            end
          else
            ruby_platform = /x86_64-darwin[\d.]+/
          end
        when /aix/
          ruby_platform = /powerpc-aix[\d.]+/
        when /solaris/
          if agent['platform'] =~ /sparc/
            ruby_platform = /sparc-solaris[\d.]+/
          else
            ruby_platform = /i386-solaris[\d.]+/
          end
        when /cisco_ios_xr/
          ruby_platform = /x86_64-linux/
        when /huaweios/
          ruby_platform = /powerpc-linux/
        else
          if agent['ruby_arch']
            ruby_platform = agent['ruby_arch'] == 'x64' ? /(x86_64|powerpc64le|aarch64)-linux/ : /(i486|i686|s390x)-linux/
          else
            ruby_platform = agent['platform'] =~ /64/ ? /(x86_64|powerpc64le|aarch64)-linux/ : /(i486|i686|s390x)-linux/
          end
      end

      has_sitedir = !on(agent, 'ruby -e"puts RbConfig::CONFIG[\'sitedir\']"').output.chomp.empty?

      expected_facts = {
          'ruby.platform' => ruby_platform,
          'ruby.version'  => ruby_version
      }
      expected_facts['ruby.sitedir'] = /\/site_ruby/ if has_sitedir

      step("verify that ruby structured fact contains facts") do
        on(agent, facter("--json ruby")) do |facter_results|
          json_facts = JSON.parse(facter_results.stdout)
          expected_facts.each do |fact, value|
            actual_fact = json_result_fact_by_key_path(json_facts, fact)
            assert_match(value, actual_fact.to_s, "Incorrect fact pattern for '#{fact}'")
          end
        end
      end
    end
  end
end
