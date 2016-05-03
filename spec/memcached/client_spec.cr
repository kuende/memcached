require "../spec_helper"

Spec2.describe Memcached::Client do
  let :client do
    Memcached::Client.new("localhost", 11211)
  end

  after do
    client.close
  end

  describe "#get and set" do
    it "sets then gets" do
      client.flush
      client.set("foo:asdf", "bar")
      expect(client.get("foo:asdf")).to eq("bar")
    end

    it "does not get non existing key" do
      expect(client.get("non:existing:key")).to eq(nil)
    end

    it "sets with expire" do
      client.flush
      client.set("expires", "soon", 2)
      expect(client.get("expires")).to eq("soon")
      sleep(3)
      expect(client.get("expires")).to eq(nil)
    end
  end

  describe "get_multi" do
    it "gets multiple keys" do
      client.flush
      client.set("key1", "value1")
      client.set("key3", "value3")

      response = client.get_multi(["key1", "key2", "key3", "key4", "key5"])
      expect(response).to eq({
        "key1": "value1",
        "key2": nil,
        "key3": "value3",
        "key4": nil,
        "key5": nil
      })
    end
  end
end
