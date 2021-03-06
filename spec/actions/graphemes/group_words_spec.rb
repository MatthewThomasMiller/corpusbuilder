require 'rails_helper'

describe Graphemes::GroupWords do
  include VersionedManagementSpecHelper

  let(:document) do
    create :document
  end

  let(:editor) do
    create :editor
  end

  let(:surface) do
    create(
      :surface,
      document_id: document.id,
      area: Area.new(ulx: 0, uly: 0, lrx: 100, lry: 20),
      number: 1,
      image_id: image1.id
    )
  end

  let(:image1) do
    create :image, image_scan: File.new(Rails.root.join("spec", "support", "files", "file_2.png")),
      name: "file_1.png",
      order: 1
  end

  let(:first_line) do
    create :zone, surface_id: surface.id, area: Area.new(ulx: 0, uly: 0, lrx: 100, lry: 20)
  end

  it 'returns proper logical when position weights across words are not monotonic' do
    _, gs = line surface, [ "abcd", "efgh", "ijkl" ], [
      [ 0, 0, 40, 10 ],
      [ 50, 0, 90, 10 ],
      [ 100, 0, 140, 10 ],
    ]

    ids = gs.map { |wgs| wgs.map(&:id) }
    Grapheme.find(ids[1]).each { |g| g.update_attributes!(position_weight: g.position_weight - 200) }

    words = Graphemes::GroupWords.run!(
      graphemes: Grapheme.find(ids)
    ).result

    expect(words.map { |w| w.map(&:value).join('') }.join(' ')).to eq('abcd efgh ijkl')
  end

  it 'returns proper logical when position weights across words are not monotonic for rtl text' do
    _, gs = line surface, [ "تصدر", "فيه", "لذلك" ], [
      [ 100, 0, 140, 10 ],
      [ 50, 0, 90, 10 ],
      [ 0, 0, 40, 10 ]
    ], :rtl

    ids = gs.map { |wgs| wgs.map(&:id) }
    Grapheme.find(ids[1]).each { |g| g.update_attributes!(position_weight: g.position_weight - 2000) }

    words = Graphemes::GroupWords.run!(
      graphemes: Grapheme.find(ids)
    ).result

    expect(words.map { |w| w.map(&:value).join('') }.join(' ')).to eq('تصدر فيه لذلك')
  end

  it 'returns no empty words for syriac line' do
    _, gs = line surface, ["ܚܼܙܐ", "ܐܢܘܢ!ܢ", "ܐܬܢܟܠ", "ܠܗ", "ܥܠܝܗܘܢ", "ْ", "ܘܡܬܛܓܖܿ", "ܗܘܐ", "ܒܗܘ"], [[1390, 2040, 1476, 2078], [1210, 2001, 1367, 2088], [1061, 2029, 1207, 2069], [976, 2029, 1032, 2070], [762, 2029, 951, 2086], [744, 2063, 750, 2069], [519, 2031, 717, 2086], [392, 2041, 489, 2071], [270, 2049, 363, 2070]], :rtl

    ids = gs.map { |wgs| wgs.map(&:id) }
    Grapheme.find(ids[1]).each { |g| g.update_attributes!(position_weight: g.position_weight - 2000) }

    words = Graphemes::GroupWords.run!(
      graphemes: Grapheme.find(ids)
    ).result

    expect(words.select { |w| w.count == 0 }.count).to eq(0)
  end

end
