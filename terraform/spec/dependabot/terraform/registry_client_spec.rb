# frozen_string_literal: true

require "spec_helper"
require "dependabot/terraform/registry_client"

RSpec.describe Dependabot::Terraform::RegistryClient do
  subject(:client) { described_class.new }

  let(:module_dependency) do
    Dependabot::Dependency.new(
      name: "hashicorp/consul/aws",
      version: "0.9.3",
      package_manager: "terraform",
      previous_version: "0.1.0",
      requirements: [{
        requirement: "0.3.8",
        groups: [],
        file: "main.tf",
        source: {
          type: "registry",
          registry_hostname: "registry.terraform.io",
          module_identifier: "hashicorp/consul/aws"
        }
      }],
      previous_requirements: [{
        requirement: "0.1.0",
        groups: [],
        file: "main.tf",
        source: {
          type: "registry",
          registry_hostname: "registry.terraform.io",
          module_identifier: "hashicorp/consul/aws"
        }
      }]
    )
  end

  it "fetches provider versions", :vcr do
    response = client.all_provider_versions(identifier: "hashicorp/aws")
    expect(response.max).to eq(Gem::Version.new("3.40.0"))
  end

  it "fetches provider versions from a custom registry" do
    hostname = "registry.example.org"
    stub_request(:get, "https://#{hostname}/v1/providers/hashicorp/aws/versions").and_return(
      status: 200,
      body: {
        "id": "hashicorp/aws",
        "versions": [{ "version": "3.42.0" }, { "version": "3.41.0" }]
      }.to_json
    )
    client = described_class.new(hostname: hostname)
    response = client.all_provider_versions(identifier: "hashicorp/aws")
    expect(response).to match_array([
      Gem::Version.new("3.42.0"),
      Gem::Version.new("3.41.0")
    ])
  end

  it "fetches provider versions form a custom registry secured by a token" do
    hostname = "registry.example.org"
    token = SecureRandom.hex(16)
    credentials = [{ "type" => "terraform_registry", "host" => hostname, "token" => token }]

    stub_request(:get, "https://#{hostname}/v1/providers/x/y/versions").
      and_return(body: { "id": "x/y", "versions": [{ "version": "0.1.0" }] }.to_json)
    client = described_class.new(hostname: hostname, credentials: credentials)

    expect(client.all_provider_versions(identifier: "x/y")).to match_array([
      Gem::Version.new("0.1.0")
    ])
    expect(WebMock).to have_requested(:get, "https://#{hostname}/v1/providers/x/y/versions").
      with(headers: { "Authorization" => "Bearer #{token}" })
  end

  it "fetches module versions", :vcr do
    response = client.all_module_versions(identifier: "hashicorp/consul/aws")
    expect(response.max).to eq(Gem::Version.new("0.9.3"))
  end

  it "fetches module versions from a custom registry" do
    hostname = "registry.example.org"
    stub_request(:get, "https://#{hostname}/v1/modules/hashicorp/consul/aws/versions").
      and_return(status: 200, body: {
        "modules": [
          {
            "source": "hashicorp/consul/aws",
            "versions": [{ 'version': "0.1.0" }, { 'version': "0.2.0" }]
          }
        ]
      }.to_json)
    client = described_class.new(hostname: hostname)
    response = client.all_module_versions(identifier: "hashicorp/consul/aws")
    expect(response).to match_array([
      Gem::Version.new("0.1.0"),
      Gem::Version.new("0.2.0")
    ])
  end

  it "raises an error when it cannot find the dependency", :vcr do
    expect { client.all_module_versions(identifier: "does/not/exist") }.to raise_error(RuntimeError) do |error|
      expect(error.message).to eq("Response from registry was 404")
    end
  end

  it "fetches the source for a module dependency", :vcr do
    source = client.source(dependency: module_dependency)

    expect(source).to be_a Dependabot::Source
    expect(source.url).to eq("https://github.com/hashicorp/terraform-aws-consul")
  end

  it "fetches the source for a provider dependency", :vcr do
    source = client.source(dependency: module_dependency)

    expect(source).to be_a Dependabot::Source
    expect(source.url).to eq("https://github.com/hashicorp/terraform-aws-consul")
  end

  it "fetches the source for a provider from a custom registry", :vcr do
    hostname = "terraform.example.org"
    client = described_class.new(hostname: hostname)
    source = client.source(dependency: Dependabot::Dependency.new(
      name: "hashicorp/ciscoasa",
      version: "1.2.0",
      package_manager: "terraform",
      requirements: [{
        requirement: "~> 1.2",
        groups: [],
        file: "main.tf",
        source: {
          type: "provider",
          registry_hostname: hostname,
          module_identifier: "hashicorp/ciscoasa"
        }
      }]
    ))

    expect(source).to be_a Dependabot::Source
    expect(source.url).to eq("https://github.com/hashicorp/terraform-provider-ciscoasa")
  end
end
