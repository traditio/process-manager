#coding=utf-8
root = File.expand_path("../..", File.dirname(__FILE__))
$:.unshift(root) unless $:.include?(root)

require "rr"
require "json"
require "master_process/threads_manager"


RSpec.configure do |config|
  config.mock_framework = :rr
end


describe MasterProcess::ThreadStateObserver do
  let!(:conn) do
    conn = Object.new
    stub(conn).close {}
    stub(conn).puts {}
    conn
  end

  subject do
    thread = Object.new
    stub(thread).thread_id { 1 }
    stub(thread).add_observer {}
    subj = MasterProcess::ThreadStateObserver.new(thread)
    stub(subj).create_connection { conn }
    subj
  end

  describe "#update" do
    after(:each) { subject.update(10) }

    it "send a command to socket" do
      mock(conn).puts('UPDATE 1 STATE 10')
    end

    it "closes the socket after sending a command" do
      mock(conn).close
    end

    it "does nothing when timeout raises during the connection to the socket" do
      mock(subject).create_connection { sleep 1.1; conn }
      do_not_allow(conn).puts
    end
  end
end


describe MasterProcess::SafeKilledThread do
  let!(:t) do
    thread = MasterProcess::SafeKilledThread.new
    stub(thread).super {}
    stub(thread).notify_observers {}
    thread
  end

  it { t.should be_a_kind_of(Observable) }

  it "the state should be 0" do
    t.state.should == 0
  end

  context "when the job is being made" do
    it "changes the state" do
      t.change_state
      t.state.should_not == 0
    end

    it "notifies observers" do
      mock(t).notify_observers(numeric)
      t.change_state
    end
  end

  context "when terminating the process" do
    it "changes the state to -1" do
      t.kill_safe
      t.state.should == -1
    end

    it "notifies observers" do
      mock(t).notify_observers(-1)
      t.kill_safe
    end

    it "kills itself" do
      mock(t).kill
      t.kill_safe
    end
  end
end


describe MasterProcess::ThreadsManager do
  subject do
    manager = MasterProcess::ThreadsManager
    stub(manager).exit {}
    stub(manager).threads_list {}
    stub(manager).join_all {}
    stub(manager).bind_to_observer {}
    stub(manager).detach_process {}
    stub(manager).new_safekilled_thread {}
    manager
  end

  describe ".kill_safe" do
    it "kills all instances of SafeKilledThread safe" do
      thread = MasterProcess::SafeKilledThread.new
      stub(thread).super {}
      stub(subject).threads_list { [thread, thread] }
      mock(thread).kill_safe.times(2) {}
      subject.kill_safe
    end

    it "exists" do
      stub(subject).threads_list { [] }
      mock(subject).exit(0)
      subject.kill_safe
    end
  end

  describe ".start" do
    it "forks and detaches the processes" do
      mock(subject).fork { 1 }
      mock(subject).detach_process(1) { 1 }
      subject.start(1)
    end
  end

  describe ".child_process" do
    context "when threads_count < 1" do
      it { expect { subject.child_process(0) }.to raise_error }
    end

    it "traps SIGTERM" do
      mock(subject).trap("TERM")
      subject.child_process(1)
    end

    it "creates N safe killed threads" do
      mock(subject).new_safekilled_thread.times(5) { 1 }
      mock(subject).bind_to_observer(1).times(5) {}
      subject.child_process(5)
    end

    it "joins the threads" do
      mock(subject).join_all {}
      subject.child_process(1)
    end
  end

end

