#coding=utf-8
root = File.expand_path("../..", File.dirname(__FILE__))
$:.unshift(root) unless $:.include?(root)

require "rr"
require "json"
require "master_process/master_process"


RSpec.configure do |config|
  config.mock_framework = :rr
end


describe MasterProcess::ProcessManagerServer do

  subject do
    class ProcessManagerServerClass
      include MasterProcess::ProcessManagerServer
    end

    process_manager = ProcessManagerServerClass.new(Hash.new)
    stub(process_manager).send_data
    stub(process_manager).notify_clients
    stub(process_manager).close_connection_after_writing
    stub(process_manager).start_threads { 5 }
    process_manager
  end

  context "when receives a command to create a process" do
    it "calls ThreadsManager.start" do
      mock(subject).start_threads(7).times(1) { 5 }
      subject.receive_line("CREATE PROCESS WITH 7 WORKERS")
    end

    it "stores the PID" do
      subject.receive_line("CREATE PROCESS WITH 7 WORKERS")
      subject.pids.keys.size.should be > 0
    end
  end

  context "when receives a command to kill" do
    context "when a process does'nt exist" do
      it "sends an error report" do
        subject.instance_variable_set(:@pids, {})
        dont_allow(subject).process_kill(9, 1000)
        mock(subject).send_data(/^ERROR/)
        subject.receive_line("KILL PROCESS 1000")
      end
    end

    context "when a process exists" do
      it "kills the process with SIGTERM" do
        subject.instance_variable_set(:@pids, {1000 => {}})
        mock(subject).process_kill(9, 1000)
        mock(subject).send_data(/^OK/)
        subject.receive_line("KILL PROCESS 1000")
      end
    end
  end

  context "when receives command to terminate" do
    context "when a process doesn't exist" do
      it "sends an error report" do
        subject.instance_variable_set(:@pids, {})
        dont_allow(subject).process_kill(15, 1000)
        mock(subject).send_data(/^ERROR/)
        subject.receive_line("TERMINATE PROCESS 1000")
      end
    end

    context "when a process exists" do
      it "kills the process with SIGKILL" do
        subject.instance_variable_set(:@pids, {1000 => {}})
        mock(subject).process_kill(15, 1000)
        mock(subject).send_data(/^OK/)
        subject.receive_line("TERMINATE PROCESS 1000")
      end
    end
  end

  context "when receives a command to update the state" do
    context "when state > 0" do
      it "saves the thread state" do
        subject.instance_variable_set(:@pids, {1000 => {}})
        subject.receive_line("UPDATE 1000#1 STATE 1")
        subject.pids.should == {1000 => {1 => 1}}
      end
    end

    context "when the state < 0 (the thread was deleted)" do
      it "deletes the thread PID from pids" do
        subject.instance_variable_set(:@pids, {1000 => {1 => 1, 2 => 1}})
        subject.receive_line("UPDATE 1000#1 STATE -1")
        subject.pids.should == {1000 => {2 => 1}}
      end

      context "when the deleted thread was the last in the process" do
        it "removes the pid of the process from pids" do
          subject.instance_variable_set :@pids, {1000 => {1 => 1}}
          subject.receive_line("UPDATE 1000#1 STATE -1")
          subject.pids.should == {}
        end
      end
    end
  end

  context "when a command raises an exception" do
    subject do
      process_manager = ProcessManagerServerClass.new([])
      stub(process_manager).send_data
      stub(process_manager).create_process { raise StandardError }
      stub(process_manager).close_connection_after_writing
      process_manager
    end

    after(:each) { subject.receive_line("CREATE PROCESS WITH 7 WORKERS") }

    it "closes the connection" do
      mock(subject).close_connection_after_writing.times(1)
    end

    it "sends an error report" do
      mock(subject).send_data(/^ERROR/).times(1)
    end
  end

  context "when a command was success" do
    subject do
      process_manager = ProcessManagerServerClass.new([])
      stub(process_manager).send_data
      stub(process_manager).create_process
      stub(process_manager).notify_clients
      stub(process_manager).close_connection_after_writing
      process_manager
    end

    after(:each) { subject.receive_line("CREATE PROCESS WITH 7 WORKERS") }

    it "closes the connection" do
      mock(subject).close_connection_after_writing.times(1)
    end

    it "notifies the web server" do
      mock(subject).notify_clients.times(1)
    end
  end

  describe '#notify_clients' do
    it "makes a POST request" do
      pids = {1000 => {1 => 1, 2 => 1}}
      subject.instance_variable_set :@pids, pids
      mock.proxy(subject).notify_clients
      mock(subject).http_post(body: {data: pids.to_json})
      subject.notify_clients
    end
  end

end