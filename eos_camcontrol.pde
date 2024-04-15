import java.util.HashSet;
import java.awt.Robot;
import java.awt.AWTException;
import java.awt.Point;
import com.jogamp.nativewindow.util.PointImmutable;
import com.jogamp.newt.opengl.GLWindow;
import com.jogamp.newt.event.KeyEvent;
import oscP5.*;
import netP5.*;

final float PI_2 = PI / 2;
HashSet<Character> keysPressed = new HashSet<Character>();
Robot robot;
Camera cam;
OscP5 oscP5;
NetAddress remoteAddr;

Boolean mouseLocked = false;
Boolean becameLocked = false;
color textBGColor = color(0, 0, 0, 64);
int TEXT_SIZE_NORMAL = 24 * displayDensity();

PVector posPrev, lookatPrev;
// float fovPrev;

void setup() {
  size(800, 800, P3D);
  textSize(TEXT_SIZE_NORMAL);
  oscP5 = new OscP5(this, 9999);
  remoteAddr = new NetAddress("192.168.1.102", 12000);
  cam = new Camera(0, 5, 10);
  posPrev = new PVector(0,0,0);
  lookatPrev = new PVector(0,0,0);
  // fovPrev = 0.0;
  // perspective(cam.fov, float(width)/float(height), 0.1, 1000);

  try {
    robot = new Robot();
  }
  catch (AWTException e) {
    e.printStackTrace();
  }

}

void draw() {
  background(32);
  cam.update(keysPressed);
  checkSendOsc();

  pushMatrix();
    perspective(radians(cam.fov), float(width)/float(height),
                cam.near_clip, cam.far_clip);
    camera(cam.pos.x, cam.pos.y, cam.pos.z,
           cam.lookAt.x, cam.lookAt.y, cam.lookAt.z,
           cam.up.x, cam.up.y, cam.up.z);

    drawAxes();
    fill(255,0,0);
    stroke(255);
    box(2);
  popMatrix();

  // 2D
  ortho();
  resetMatrix();
  translate(-width/2, -height/2);
  drawInfo(20, 20, 350, 300);

  drawHorizon();

  if (mouseLocked) {
    centerMouse();
  }
}


void drawAxes() {
  int len = 10000;
  color grey = color(128,128,128);

  // X
  stroke(255,0,0);
  line(0, 0, 0, len, 0, 0);
  stroke(grey);
  line(0, 0, 0, -len, 0, 0);
  // Y
  stroke(0,255,0);
  line(0, 0, 0, 0, len, 0);
  stroke(grey);
  line(0, 0, 0, 0, -len, 0);
  // Z
  stroke(0,0,255);
  line(0, 0, 0, 0, 0, len);
  stroke(grey);
  line(0, 0, 0, 0, 0, -len);
}

void drawHorizon() {
  float horizonY = cam.pos.y + map(cam.alt, -radians(cam.fov)/2, radians(cam.fov)/2, 0, height);
  noFill();
  stroke(255, 0, 255);
  strokeWeight(1);
  line(0, horizonY, width, horizonY);
}

void drawInfo(float x, float y, float w, float h) {
  float margin = 12;
  float textOriginX = x+ margin;
  float textOriginY = y+ margin + TEXT_SIZE_NORMAL/2;
  float labelX = textOriginX;
  float valueX = labelX + w/3;
  float lineSpace = TEXT_SIZE_NORMAL + 10;
  int lineCount = 0;
  float textOffsetY = 0; // = textOriginY + lineSpace*lineCount;
  

  noStroke();
  fill(textBGColor);
  rect (x, y, w, h, 16);
  
  fill(255);

  // Camera Pos
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String posValue = String.format("[%.2f, %.2f, %.2f]",
                                      cam.pos.x, cam.pos.y, cam.pos.z);
  text("Viewpoint", labelX, textOffsetY);
  text(posValue, valueX, textOffsetY);

  // Camera Lookat
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String lookatValue = String.format("[%.2f, %.2f, %.2f]",
                                     cam.lookAt.x, cam.lookAt.y, cam.lookAt.z);
  text("Look at", labelX, textOffsetY);
  text(lookatValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String vpnValue = String.format("[%.2f, %.2f, %.2f]",
                                  cam.vpn.x, cam.vpn.y, cam.vpn.z);
  text("VPN", labelX, textOffsetY);
  text(vpnValue, valueX, textOffsetY);

  textOffsetY = textOriginY + lineSpace*lineCount++;
  String azValue = String.format("%.2f", degrees(cam.az));
  text("Azimuth", labelX, textOffsetY);
  text(azValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String altValue = String.format("%.2f", degrees(cam.alt));
  text("Altitude", labelX, textOffsetY);
  text(altValue, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String fovValue = String.format("%.2f", cam.fov);
  // String fovValue = String.format("%.2f", degrees(cam.fov));
  text("FOV", labelX, textOffsetY);
  text(fovValue, valueX, textOffsetY);

  textOffsetY = textOriginY + lineSpace*lineCount++;
  String nearVal = String.format("%.2f", cam.near_clip);
  text("Near clip", labelX, textOffsetY);
  text(nearVal, valueX, textOffsetY);
  
  textOffsetY = textOriginY + lineSpace*lineCount++;
  String farVal = String.format("%.2f", cam.far_clip);
  text("Far clip", labelX, textOffsetY);
  text(farVal, valueX, textOffsetY);


}



void keyPressed() {
  keysPressed.add(key);
}

void keyReleased() {
  keysPressed.remove(key);
}


void keyTyped() {
  switch(key) {
    case ' ':
      setMouseLock(!mouseLocked);
      break;
    case '0':
      cam.pos = new PVector(0,0,0);
      break;
    // case '=':
    //   cam.fov += 0.1;
    //   break;
    // case '-':
    //   cam.fov -= 0.1;
    //   break;
      
  }
}

void centerMouse() {
   PointImmutable locationImmutable = ((GLWindow)surface.getNative()).getLocationOnScreen(null);
  Point location = new Point(locationImmutable.getX(), locationImmutable.getY());

  int centerX = location.x + width / 2;
  int centerY = location.y + height / 2;
  robot.mouseMove(centerX, centerY);
}

void setMouseLock(Boolean isLocked) {
  mouseLocked = isLocked;
  if (mouseLocked) {
    becameLocked = true;
    noCursor();
  }
  else {
    cursor();
  }
}

class Camera {
  PVector pos, lookAt, vel, vpn, up;
  float near_clip, far_clip;
  float az, alt, azVel, altVel;
  float dampR, dampM, fov, accel_force,
        breaking_force, zRot;

  Camera(float x, float y, float z) {
    pos = new PVector(x, y, z);
    lookAt = new PVector(0, 0, 0);
    near_clip = 0.5;
    far_clip = 20;
    vel = new PVector(0, 0, 0);
    vpn = new PVector(0, 0, -1);
    up = new PVector(0, -1, 0);
    az = 270;
    alt = 0;
    azVel = 0;
    altVel = 0;
    dampR = 0.0005;
    dampM = 0.002;
    fov = 60; // PI / 3;
    accel_force = 20.0;
    breaking_force = 10.0; 
    zRot = 0;
  }

  void update(HashSet<Character> keys) {
     // float accel_force = 20;
    float dt = 1.0 / frameRate;
    if (keys.contains('w')) {
      PVector forward_force = PVector.mult(vpn, dt*accel_force);
      vel = vel.sub(forward_force);
    }
    if (keys.contains('s')) {
      PVector backward_force = PVector.mult(vpn, dt*-accel_force);
      vel = vel.sub(backward_force);
    }
    if (keys.contains('a')) {
      PVector strafe = PVector.mult(vpn.cross(up).normalize(), dt*accel_force);
      vel.add(strafe);
    }
    if (keys.contains('d')) {
      PVector strafe = PVector.mult(vpn.cross(up).normalize(), dt*-accel_force);
      vel.add(strafe);
    }

    if (keys.contains('e')) {
      vel.add(PVector.mult(up, dt*accel_force));
    }
    if (keys.contains('c')) {
      vel.sub(PVector.mult(up, dt*accel_force));
    }
    if (keys.contains('x')) {
      PVector brakingForce = PVector.mult(vel, breaking_force * dt * -1);
      vel.add(brakingForce);
    }

    if (keys.contains('-')) {
      cam.fov -= 0.1;
      sendOscFloat("/camcontrol/cam/fov", cam.fov);
    }
    if (keys.contains('=')) {
      cam.fov += 0.1;
      sendOscFloat("/camcontrol/cam/fov", cam.fov);
    }
    
    if (keys.contains('n')) {
      cam.near_clip -= 0.01;
      sendOscFloat("/camcontrol/cam/near", cam.near_clip);
    }
    if (keys.contains('N')) {
      cam.near_clip += 0.01;
      sendOscFloat("/camcontrol/cam/near", cam.near_clip);
    }
    if (keys.contains('f')) {
      cam.far_clip -= 0.1;
      sendOscFloat("/camcontrol/cam/far", cam.far_clip);
    }
    if (keys.contains('F')) {
      cam.far_clip += 0.1;
      sendOscFloat("/camcontrol/cam/far", cam.far_clip);
    }

    updateOrientationAndPosition(dt);
  }

  void updateOrientationAndPosition(float dt) {
    float mouseXScale = (mouseX - width / 2) * 0.5;
    float mouseYScale = -(mouseY - height / 2) * 0.5;
    final float epsilon = 0.00001;
    mouseXScale = (mouseLocked && !becameLocked) ? mouseXScale : 0;
    mouseYScale = (mouseLocked && !becameLocked) ? mouseYScale : 0;
    becameLocked = false;

    azVel += mouseXScale * dt*10;
    altVel += mouseYScale * dt*10;

    float dampRDt = pow(dampR, dt);
    float dampMDt = pow(dampM, dt);

    az += azVel * (1 - dampRDt) / log(dampR);
    alt += altVel * (1 - dampRDt) / log(dampR);

    azVel *= dampRDt;
    altVel *= dampRDt;

    az = (az % TWO_PI + TWO_PI) % TWO_PI;
    alt = constrain(alt, -PI_2+epsilon, PI_2-epsilon);

    vpn.x = cos(alt) * cos(az);
    vpn.y = sin(alt);
    vpn.z = cos(alt) * sin(az);
    vpn.normalize();

    PVector scaledVel = PVector.mult(vel, (1 - dampMDt) / log(dampM));
    pos.add(scaledVel);
    // friction
    vel.mult(dampMDt);

    lookAt = PVector.add(pos, PVector.mult(vpn, 10));
  }
}

void checkSendOsc() {
  if (! posPrev.equals(cam.pos) ) {
    OscMessage posMsg = new OscMessage("/camcontrol/cam/pos");
    posMsg.add(cam.pos.x);
    posMsg.add(cam.pos.y);
    posMsg.add(cam.pos.z);
    oscP5.send(posMsg, remoteAddr);
    posPrev = cam.pos.copy();
  }

  if (! lookatPrev.equals(cam.lookAt)) {
    OscMessage lookAtMsg = new OscMessage("/camcontrol/cam/lookat");
    lookAtMsg.add(cam.lookAt.x);
    lookAtMsg.add(cam.lookAt.y);
    lookAtMsg.add(cam.lookAt.z);
    oscP5.send(lookAtMsg, remoteAddr);
    lookatPrev = cam.lookAt.copy();
  }
}

void sendOscFloat(String oscId, float value) {
  OscMessage msg = new OscMessage(oscId);
  msg.add(value);
  oscP5.send(msg, remoteAddr);
}
