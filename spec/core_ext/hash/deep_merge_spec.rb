require "gorgon/core_ext/hash/deep_merge"

describe "#deep_merge" do
  example do
    hash_1 = { a: "a", b: "b", c: { c1: "c1", c2: "c2", c3: { d1: "d1" } } }
    hash_2 = { a: 1, c: { c1: 2, c3: { d2: "d2" } } }
    expected = { a: 1, b: "b", c: { c1: 2, c2: "c2", c3: { d1: "d1", d2: "d2" } } }

    expect(hash_1.deep_merge(hash_2)).to eq(expected)
  end
end
