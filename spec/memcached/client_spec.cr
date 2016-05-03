require "../spec_helper"

Spec2.describe Memcached::Client do
  let :client do
    Memcached::Client.new("localhost", 11211)
  end

  before do
    client.flush
  end

  after do
    client.close
  end

  describe "#get and set" do
    it "sets then gets" do
      client.set("foo:asdf", "bar")
      expect(client.get("foo:asdf")).to eq("bar")
    end

    it "does not get non existing key" do
      expect(client.get("non:existing:key")).to eq(nil)
    end

    it "sets with expire" do
      client.set("expires", "soon", 2)
      expect(client.get("expires")).to eq("soon")
      sleep(3)
      expect(client.get("expires")).to eq(nil)
    end
  end

  describe "get_multi" do
    it "gets multiple keys" do
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

  describe "add" do
    it "adds to nil value" do
      client.add("foo", "value")
      expect(client.get("foo")).to eq("value")
    end

    it "adds multiple times" do
      client.set("foo", "value1")
      expect do
        client.add("foo", "value2")
      end.to raise_error(Memcached::NotStoredError)
      expect(client.get("foo")).to eq("value1")
    end
  end

  describe "delete" do
    it "deletes existing key" do
      client.set("foo", "value")
      expect(client.delete("foo")).to eq(true)
      expect(client.get("foo")).to eq(nil)
    end

    it "deletes not existing key" do
      expect(client.delete("foo")).to eq(false)
    end
  end
end
