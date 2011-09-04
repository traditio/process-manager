require "rr"
require "json"
require_relative "../../master_process/master_process"


RSpec.configure do |config|
  config.mock_framework = :rr
end


describe ProcessManagerServer do

  subject do
    class ProcessManagerServerClass
      include ProcessManagerServer
    end
    p = ProcessManagerServerClass.new(Hash.new)
    stub(p).send_data
    stub(p).notify_clients
    stub(p).close_connection_after_writing
    stub(p).start_threads { 5 }
    p
  end

  context "when receive command to create" do
    it "call ThreadsManager.start" do
      mock(subject).start_threads(7).times(1) { 5 }
      subject.receive_line("CREATE PROCESS WITH 7 WORKERS\n")
    end
    it "creates key in pids" do
      subject.receive_line("CREATE PROCESS WITH 7 WORKERS\n")
      subject.pids.should_not be_empty
    end
  end

  context "when receive command to kill" do

    context "when process doesnot exist" do
      it "send error report" do
        subject.instance_variable_set :@pids, {}
        dont_allow(subject).process_kill(9, 1000)
        mock(subject).send_data(/^ERROR/)
        subject.receive_line("KILL PROCESS 1000")
      end
    end

    context "when process exist" do
      it "kill process with SIGTERM" do
        subject.instance_variable_set :@pids, {1000 =>{}}
        mock(subject).process_kill(9, 1000)
        mock(subject).send_data(/^OK/)
        subject.receive_line("KILL PROCESS 1000")
      end
    end

  end

  context "when receive command to terminate" do

    context "when process doesnot exist" do
      it "send error report" do
        subject.instance_variable_set :@pids, {}
        dont_allow(subject).process_kill(15, 1000)
        mock(subject).send_data(/^ERROR/)
        subject.receive_line("TERMINATE PROCESS 1000")
      end
    end

    context "when process exist" do
      it "kill process with SIGKILL" do
        subject.instance_variable_set :@pids, {1000 =>{}}
        mock(subject).process_kill(15, 1000)
        mock(subject).send_data(/^OK/)
        subject.receive_line("TERMINATE PROCESS 1000")
      end
    end

  end

  context "when receive command to update stats" do

    context "when state > 0" do
      it "save thread state" do
        subject.instance_variable_set :@pids, {1000 => {}}
        subject.receive_line("UPDATE 1000#1 STATE 1")
        subject.pids.should == {1000 => {1 => 1}}
      end
    end

    context "when state < 0 (thread deleted)" do

      it "delete thread from pids" do
        subject.instance_variable_set :@pids, {1000 => {1 => 1, 2 => 1}}
        subject.receive_line("UPDATE 1000#1 STATE -1")
        subject.pids.should == {1000 => {2 => 1}}
      end

      context "when deleted thread was last in process" do
        it "remove pid of process from pids" do
          subject.instance_variable_set :@pids, {1000 => {1 => 1}}
          subject.receive_line("UPDATE 1000#1 STATE -1")
          subject.pids.should == {}
        end
      end

    end

  end

  context "when command raises exception" do
    subject {
      p = ProcessManagerServerClass.new []
      stub(p).send_data
      stub(p).create_process { raise Exception }
      stub(p).close_connection_after_writing
      p
    }
    after(:each) { subject.receive_line("CREATE PROCESS WITH 7 WORKERS\n") }
    it "closes connection" do
      mock(subject).close_connection_after_writing.times(1)
    end
    it "sends error report" do
      mock(subject).send_data(/^ERROR/).times(1)
    end
  end

  context "when command was success" do
    subject {
      p = ProcessManagerServerClass.new []
      stub(p).send_data
      stub(p).create_process
      stub(p).notify_clients
      stub(p).close_connection_after_writing
      p
    }
    after(:each) { subject.receive_line("CREATE PROCESS WITH 7 WORKERS\n") }
    it "closes connection" do
      mock(subject).close_connection_after_writing.times(1)
    end
    it "notifies web server" do
      mock(subject).notify_clients.times(1)
    end
  end

  describe '#notify_clients' do
    it "make http post" do
      pids = {1000 => {1 => 1, 2 => 1}}
      subject.instance_variable_set :@pids, pids
      mock.proxy(subject).notify_clients
      mock(subject).http_post :body => {:data => pids.to_json}
      subject.notify_clients
    end
  end

end