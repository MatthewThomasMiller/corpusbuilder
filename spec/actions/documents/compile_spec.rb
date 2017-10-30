require 'rails_helper'

describe Documents::Compile do
  include ActiveJob::TestHelper

  let(:elements) do
    [
      Parser::Element.new(name: "surface", area: Area.new(lrx: 100, lry: 10, ulx: 0, uly: 0)),
      Parser::Element.new(name: "zone", area: Area.new(lrx: 60, lry: 10, ulx: 0, uly: 0)),
      Parser::Element.new(name: "grapheme", certainty: 0.1, area: Area.new(lrx: 10, lry: 10, ulx: 0, uly: 0), value: 'h'),
      Parser::Element.new(name: "grapheme", certainty: 0.2, area: Area.new(lrx: 20, lry: 10, ulx: 10, uly: 0), value: 'e'),
      Parser::Element.new(name: "grapheme", certainty: 0.3, area: Area.new(lrx: 30, lry: 10, ulx: 20, uly: 0), value: 'l'),
      Parser::Element.new(name: "grapheme", certainty: 0.4, area: Area.new(lrx: 40, lry: 10, ulx: 30, uly: 0), value: 'l'),
      Parser::Element.new(name: "grapheme", certainty: 0.5, area: Area.new(lrx: 50, lry: 10, ulx: 40, uly: 0), value: 'o'),
      Parser::Element.new(name: "zone", area: Area.new(lrx: 60, lry: 20, ulx: 0, uly: 10)),
      Parser::Element.new(name: "grapheme", certainty: 0.7, area: Area.new(lrx: 20, lry: 20, ulx: 10, uly: 10), value: 'o'),
      Parser::Element.new(name: "grapheme", certainty: 0.6, area: Area.new(lrx: 10, lry: 20, ulx: 0, uly: 10), value: 'w'),
      Parser::Element.new(name: "grapheme", certainty: 0.8, area: Area.new(lrx: 30, lry: 20, ulx: 20, uly: 10), value: 'r'),
      Parser::Element.new(name: "grapheme", certainty: 0.9, area: Area.new(lrx: 40, lry: 20, ulx: 30, uly: 10), value: 'l'),
      Parser::Element.new(name: "grapheme", certainty: 0.99, area: Area.new(lrx: 50, lry: 20, ulx: 40, uly: 10), value: 'd')
    ].lazy
  end

  let(:parser) do
    instance_double("TeiParser", elements: elements)
  end

  let(:proper_params) do
    {
      image_ocr_result: parser,
      document: document,
      image_id: image.id
    }
  end

  let(:no_results_params) do
    {
      document: document
    }
  end

  let(:no_document_params) do
    {
      image_ocr_result: parser
    }
  end

  let(:document) do
    create :document, status: Document.statuses[:processing]
  end

  let(:image) do
    create :image,
      name: "file_2.png",
      order: 1,
      image_scan: File.new(Rails.root.join("spec", "support", "files", "file_2.png"))
  end

  let(:surfaces) do
    Surface.where(document_id: document.id)
  end

  let(:zones) do
    Zone.where(surface_id: surfaces.first.id).sort_by do |zone|
      zone.area.lry
    end
  end

  let(:graphemes) do
    Grapheme.joins(:zone).where(zones: { surface_id: surfaces.first.id })
  end

  let(:proper_call) do
    Documents::Compile.run proper_params
  end

  let(:no_document_call) do
    Documents::Compile.run no_document_params
  end

  let(:no_results_call) do
    Documents::Compile.run no_results_params
  end

  it "proper call ends up being a valid action" do
    expect(proper_call).to be_valid
  end

  it "fails when no document is given" do
    expect(no_document_call).not_to be_valid
  end

  it "fails when no ocr results are given" do
    expect(no_results_call).not_to be_valid
  end

  it "creates proper surfaces" do
    proper_call

    expect(surfaces.count).to eq(1)
    expect(surfaces.first.number).to eq(image.order)
    expect(surfaces.first.area).to eq(Area.new(lrx: 100, lry: 10, ulx: 0, uly: 0))
  end

  it "properly creates zones" do
    proper_call

    expect(zones.count).to eq(2)
    expect(zones.first.area).to eq(Area.new(lrx: 60, lry: 10, ulx: 0, uly: 0))
    expect(zones.last.area).to eq(Area.new(lrx: 60, lry: 20, ulx: 0, uly: 10))
  end

  it "properly creates graphemes" do
    proper_call

    expect(graphemes.count).to eq(10)
    expect(graphemes.map(&:status).uniq).to eq(["regular"])
    expect(graphemes[4].value).to eq('o')
    expect(graphemes[4].certainty).to eq(0.5)
    expect(graphemes[4].zone_id).to eq(zones.first.id)
    expect(graphemes[9].value).to eq('d')
    expect(graphemes[9].certainty).to eq(0.99)
    expect(graphemes[9].zone_id).to eq(zones.last.id)
  end

  it "attaches position_weight values corresponding to the exact place of the grapheme inside the stream of results" do
    proper_call

    expect(graphemes.map(&:position_weight)).to eq((1..(graphemes.count)).to_a)
    expect(graphemes.map(&:value).join).to eq("helloowrld")
  end
end

