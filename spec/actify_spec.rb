# frozen_string_literal: true

RSpec.describe Actify do
  it "has a version number" do
    expect(Actify::VERSION).not_to be nil
  end

  it "performs an action" do
    expect(Actify.perform("run")).to eq("Performing: run")
  end
end
