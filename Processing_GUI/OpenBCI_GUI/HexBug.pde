

//////////////////////////////////////////////////////////////
//
// This class creates and manages the messaging to the Hex Bug
//
// Created: Chip Audette, May-June 2014
//
///////////////////////////////////////////////////////////////

class HexBug {
  
  //create inner class to wrap up a "command"
  class Command {
    private String command_str;
    private String name;
    private int counter;
    private Serial serial_h;
    public boolean printReceivedCommand = false;
    public int ID;
    
    Command(Serial _serial_h, String _str, String _name, int _ID) {
      serial_h = _serial_h;
      command_str = _str;
      name =_name;
      counter = 0;
      ID = _ID;
    }
    
    public int issue() {
      counter++;
      if (printReceivedCommand) println("HexBug: Command: " + name + " (" + counter + ")");
      if (serial_h != null) serial_h.write(command_str + "\n");
      return ID;
    }
  } //close definition of class Command
    
  private Command command_fire, command_forward, command_left, command_right; 
  private int prev_command = -1;
  
  //Constructor, pass in an already-opened serial port
  HexBug(Serial serialPort) {
    int ID = 0;
    command_fire = new Command(serialPort,"|","Fire!",ID++);
    command_left = new Command(serialPort,"{","Left",ID++);
    command_right = new Command(serialPort,"}","Right",ID++);
    command_forward = new Command(serialPort,"P","Forward",ID++);
  }
  
  public void fire() {
    prev_command = command_fire.issue();
  }
  public void forward() {
    if (prev_command != command_forward.ID) prev_command = command_fire.issue();  //issue a FIRE command on a transition
    prev_command = command_forward.issue();
  }
  public void left() {
    if (prev_command != command_left.ID) prev_command = command_fire.issue();  //issue a FIRE command on a transition
    prev_command = command_left.issue();
  }
  public void right() {
    if (prev_command != command_right.ID) prev_command = command_fire.issue();  //issue a FIRE command on a transition
    prev_command = command_right.issue();
  }

}
