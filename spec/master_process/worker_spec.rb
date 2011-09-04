require "rr"
require "json"
require_relative "../../master_process/worker"


RSpec.configure do |config|
  config.mock_framework = :rr
end


describe ThreadStateObserver do

  let!(:conn) {
    conn=Object.new
    stub(conn).close {}
    stub(conn).puts {}
    conn
  }
  subject do
    thread = Object.new
    stub(thread).thread_id { 1 }
    stub(thread).add_observer {}


    subj = ThreadStateObserver.new thread
    stub(subj).create_connection { conn }
    subj

  end

  describe "#update" do

    after(:each) { subject.update(10) }
    it "puts command to socket" do
      mock(conn).puts('UPDATE 1 STATE 10')
    end

    it "closes socket after putting command" do
      mock(conn).close
    end

    it "do not nothing when timeout to socket connectin" do
      mock(subject).create_connection { sleep 1.1 }
      do_not_allow(conn).puts
    end

  end
end


describe SafeKilledThread do


  let!(:t) do
    t = SafeKilledThread.new
    stub(t).super {}
    stub(t).notify_observers {}
    stub(t).kill {}
    t
  end

  after(:each) { t.kill() }

  it { t.should be_a_kind_of(Observable) }

  it "state should be 0" do
    t.state.should == 0
  end

  context "when run the job" do

    it "change state" do
      t.job()
      t.state.should_not == 0
    end

    it "notify obeservers" do
      mock(t).notify_observers(numeric)
      t.job()
    end

  end
  context "when terminate (soft killing)" do

    it "change state to -1" do
      t.soft_kill()
      t.state.should == -1
    end

    it "notify_observers" do
      mock(t).notify_observers(-1)
      t.soft_kill()
    end

    it "self killing" do
      mock(t).kill
      t.soft_kill()
    end

  end

end


describe ThreadsManager do

  subject {
    tm = ThreadsManager
    stub(tm).exit {}
    stub(tm).threads_list {}
    stub(tm).join_threads {}
    stub(tm).bind_to_observer {}
    stub(tm).detach_process {}
    stub(tm).new_safekilled_thread {}
    tm
  }

  describe ".soft_kill" do

    it "soft kill all instances of SafeKilledThread" do
      t = SafeKilledThread.new
      stub(t).super {}
      stub(subject).threads_list {[t, t]}
      mock(t).soft_kill().times(2) {}
      subject.soft_kill()
    end

    it "exit" do
      stub(subject).threads_list {[]}
      mock(subject).exit(0)
      subject.soft_kill()
    end

  end

  describe ".start" do

    it "forks and detach" do
      mock(subject).fork { 1 }
      mock(subject).detach_process(1) { 1 }
      subject.start(1)
    end

  end

  describe ".child_process" do

    context "when threads_count < 1" do
      it do expect { subject.child_process(0) }.to raise_error end
    end

    it "traps sigterm" do
      mock(subject).trap("TERM")
      subject.child_process(1)
    end

    it "makes N safe killed threads" do
      mock(subject).new_safekilled_thread.times(5) {1}
      mock(subject).bind_to_observer(1).times(5) {}
      subject.child_process(5)
    end

    it "joins thhreads" do
      mock(subject).join_threads {}
      subject.child_process(1)
    end

  end

end

