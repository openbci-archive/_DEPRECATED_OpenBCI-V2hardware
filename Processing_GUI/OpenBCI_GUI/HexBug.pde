

//////////////////////////////////////////////////////////////
//
// This class creates and manages the messaging to the Hex Bug
//
// Created: Chip Audette, May-June 2014
//
///////////////////////////////////////////////////////////////

class HexBug {
  
  final String command_fire = "|";
  final String command_forward = "P";
  final String command_left = "{";
  final String command_right = "}";
  Serial serial_HexBug = null;
  boolean printReceivedCommand = true;
  
  //Constructor, pass in an already-opened serial port
  HexBug(Serial serialPort) {
    serial_HexBug = serialPort;
  }
  
  public void fire() {
    issue_command(command_fire);
    if (printReceivedCommand) println("HexBug: fire!");
  }
  public void forward() {
    issue_command(command_forward);
    if (printReceivedCommand) println("HexBug: forward");
  }
  public void left() {
    issue_command(command_left);
    if (printReceivedCommand) println("HexBug: left");
  }
  public void right() {
    issue_command(command_right);
    if (printReceivedCommand) println("HexBug: right");
  }
  public void issue_command(String command) {
    if (serial_HexBug != null) {
      serial_HexBug.write(command + "\n");
    }
  }

}
