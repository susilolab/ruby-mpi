require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MPI" do
  before(:all) do
    MPI.Init()
  end
  after(:all) do
    MPI.Finalize()
  end

  before do
    @world = MPI::Comm::WORLD
  end

  it "should give version" do
    MPI::VERSION.class.should eql(Fixnum)
    MPI::SUBVERSION.class.should eql(Fixnum)
  end

  it "should give rank and size" do
    @world.rank.class.should eql(Fixnum)
    @world.size.class.should eql(Fixnum)
    @world.size.should > 0
  end

  it "should send and receive String" do
    rank = @world.rank
    message = "Hello from #{rank}"
    tag = 0
    @world.Send(message, 0, tag) if rank != 0
    if rank == 0
      (@world.size-1).times do |i|
        str = " "*"Hello from #{i+1}".length
        status = @world.Recv(str, i+1, tag)
        status.source.should eql(i+1)
        status.tag.should eql(tag)
        str.should match(/\AHello from #{i+1}/)
      end
    end
  end

  it "should send and receive NArray" do
    tag = 1
    rank = @world.rank
    [NArray[1,2,3], NArray[3.0,2.0,1.0]].each do |ary0|
      ary0 = NArray[1,2,3]
      @world.Send(ary0, 0, tag) if rank != 0
      if rank == 0
        (@world.size-1).times do |i|
          ary1 = NArray.new(ary0.typecode, ary0.total)
          status = @world.Recv(ary1, i+1, tag)
          status.source.should eql(i+1)
          status.tag.should eql(tag)
          ary1.should == ary0
        end
      end
    end
  end

  it "should send and receive without blocking" do
    tag = 2
    rank = @world.rank
    message = "Hello from #{rank}"
    if rank != 0
      request = @world.Isend(message, 0, tag)
      status = request.Wait
    end
    if rank == 0
      (@world.size-1).times do |i|
        str = " "*"Hello from #{i+1}".length
        request_recv = @world.Irecv(str, i+1, tag)
        status = request_recv.Wait
        status.source.should eql(i+1)
        status.tag.should eql(tag)
        str.should match(/\AHello from #{i+1}/)
      end
    end
  end

  it "should gather data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = rank == root ? "?"*bufsize*size  : nil
    @world.Gather(sendbuf, recvbuf, root)
    if rank == root
      str = ""
      size.times{|i| str << i.to_s*bufsize}
      recvbuf.should eql(str)
    end
  end

  it "should gather data to all processes (allgather)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = "?"*bufsize*size
    @world.Allgather(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    recvbuf.should eql(str)
  end

  it "should broad cast data (bcast)" do
    rank = @world.rank
    root = 0
    bufsize = 2
    if rank == root
      buffer = rank.to_s*bufsize
    else
      buffer = " "*bufsize
    end
    @world.Bcast(buffer, root)
    buffer.should eql(root.to_s*bufsize)
  end

  it "should scatter data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    if rank == root
      sendbuf = ""
      size.times{|i| sendbuf << i.to_s*bufsize}
    else
      sendbuf = nil
    end
    recvbuf = " "*bufsize
    @world.Scatter(sendbuf, recvbuf, root)
    recvbuf.should eql(rank.to_s*bufsize)
  end

  it "should send and recv data (sendrecv)" do
    rank = @world.rank
    size = @world.size
    dest = rank-1
    dest = size-1 if dest < 0
    #dest = MPI::PROC_NULL if dest < 0
    source = rank+1
    source = 0 if source > size-1
    #source = MPI::PROC_NULL if source > size-1
    sendtag = rank
    recvtag = source
    bufsize = 2
    sendbuf = rank.to_s*bufsize
    recvbuf = " "*bufsize
    @world.Sendrecv(sendbuf, dest, sendtag, recvbuf, source, recvtag);
    if source != MPI::PROC_NULL
      recvbuf.should  eql(source.to_s*bufsize)
    end
  end

  it "should change data between each others (alltoall)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = rank.to_s*bufsize*size
    recvbuf = "?"*bufsize*size
    @world.Alltoall(sendbuf, recvbuf)
    str = ""
    size.times{|i| str << i.to_s*bufsize}
    recvbuf.should eql(str)
  end

  it "should reduce data" do
    rank = @world.rank
    size = @world.size
    root = 0
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = rank == root ? NArray.new(sendbuf.typecode,bufsize) : nil
    @world.Reduce(sendbuf, recvbuf, MPI::Op::SUM, root)
    if rank == root
      ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
      recvbuf.should == ary
    end
  end

  it "should reduce data and send to all processes (allreduce)" do
    rank = @world.rank
    size = @world.size
    bufsize = 2
    sendbuf = NArray.to_na([rank]*bufsize)
    recvbuf = NArray.new(sendbuf.typecode,bufsize)
    @world.Allreduce(sendbuf, recvbuf, MPI::Op::SUM)
    ary = NArray.new(sendbuf.typecode,bufsize).fill(size*(size-1)/2.0)
    recvbuf.should == ary
  end

  it "should not raise exception in calling barrier" do
    @world.Barrier
  end


  it "shoud raise exeption" do
    lambda{ @world.Send("", @world.size+1, 0) }.should raise_error(MPI::ERR::RANK)
    @world.Errhandler.should eql(MPI::Errhandler::ERRORS_RETURN)
  end

end
