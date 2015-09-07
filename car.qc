/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/
void(vector org) gunshot = 
{
  WriteByte (MSG_MULTICAST, SVC_TEMPENTITY);
  WriteByte (MSG_MULTICAST, TE_GUNSHOT);
  WriteByte (MSG_MULTICAST, 3);
  WriteCoord (MSG_MULTICAST, org_x);
  WriteCoord (MSG_MULTICAST, org_y);
  WriteCoord (MSG_MULTICAST, org_z);
  multicast (org, MULTICAST_PVS);
}
float(float normalize) fnorm = {
  if(normalize == 0)
    return 0;
  if(normalize < 0)
    return -1;
  else
    return 1;
};
float(float v) anglemod =
{
  if (v > 0)
    {
      if (v > 180)
	v = v - 360;
    }
  else
    {
      if (v < -180)
	v = v + 360;
    }
  return v;
};
float(float v) anglemod90 =
{
  if (v > 0)
    {
      if (v > 90)
	v = v - 180;
    }
  else
    {
      if (v < -90)
	v = v + 180;
    }
  return v;
};
vector(vector v) vectormod =
{
  v_x = anglemod(v_x);
  v_y = anglemod(v_y);
  v_z = anglemod(v_z);
  return v;
};
float(float a1, float a2) angledif = {
  local float move;
  move = anglemod(a1) - anglemod(a2);
  move = anglemod(move);
  if (a1 > a2)
    {
      if (move > 180)
	move = move - 360;
    }
  else
    {
      if (move < -180)
	move = move + 360;
    }
  move = anglemod(move);
  return move;
};
vector(vector v1, vector v2) vectordif = 
{
  local vector v;
  v_x = angledif(v1_x, v2_x);
  v_y = angledif(v1_y, v2_y);
  v_z = angledif(v1_z, v2_z);
  return v;
};
void() t_trackcenter = {
  local float anglez;
  anglez = self.angles_z;
  self.movetarget = self.goalentity = find (world, targetname, self.target);
  self.velocity = self.speed * normalize (self.movetarget.origin - self.origin);
  self.angles = vectoangles(self.movetarget.origin - self.origin);
  self.angles_z = anglez;
  self.nextthink = time;
};

#define WIDE 64
vector(vector org, vector dir) findsurface = {
  local vector rot = '0 0 0';
  makevectors(dir);
  traceline(org, org + v_forward * WIDE - v_up * 64, FALSE, self);
  rot_x += 1-trace_fraction;
  traceline(org, org - v_forward * WIDE - v_up * 64, FALSE, self);
  rot_x -= 1-trace_fraction;
  traceline(org, org + v_right * WIDE - v_up * 64, FALSE, self);
  rot_z += 1-trace_fraction;
  traceline(org, org - v_right * WIDE - v_up * 64, FALSE, self);
  rot_z -= 1-trace_fraction;
  //rot_x *= -1;
  rot_z *= -1;
  if(fabs(rot_x) < 0.01)
    rot_x = 0;
  if(fabs(rot_z) < 0.01)
    rot_z = 0;
  return rot;
};
vector(vector parent, vector pole, vector orig, float t) vecrotate = {
  t *= DEG2RAD;
  local vector result;
  local float x, y, z, a, b, c, u, v, w;
  x = parent_x;
  y = parent_y;
  z = parent_z;
  u = pole_x;
  v = pole_y;
  w = pole_z;
  a = orig_x;
  b = orig_y;
  c = orig_z;
  result_x = (a*(v*v + w*w) - u*(b*v + c*w - u*x - v*y - w*z))*(1-cos(t)) + x*cos(t) + (0-c*v + b*w - w*y + v*z)*sin(t);
  result_y = (b*(u*u + w*w) - v*(a*u + c*w - u*x - v*y - w*z))*(1-cos(t)) + y*cos(t) + (c*u - a*w + w*x - u*z)*sin(t);
  result_z = (c*(u*u + v*v) - w*(a*u + b*v - u*x - v*y - w*z))*(1-cos(t)) + z*cos(t) + (0-b*u + a*v - v*x + u*y)*sin(t);
  return result;
};
vector(entity ent, vector raxis, float angle) entrotate = {//Rotates an entity about an axis, uses functions: vecrotate, vectordif
  local vector angledelta = ent.angles;
  local float z, rolloffset;
  makevectors(ent.angles);
  v_forward = vecrotate(v_forward, raxis, ent.origin, angle); //rotate v_forward around axis

  z = ent.angles_z;

  ent.angles = vectoangles(v_forward);
  
  angledelta = vectordif(ent.angles, angledelta);//change in angles from roll, new z angle will be 0
  rolloffset = 0-(v_forward * '0 0 1') * angledelta_y; //removes x angle aberration
  ent.angles_z = z + (angle * (v_forward * raxis)) + rolloffset;//add z changes

  ent.angles_x *= -1;
  return ent.angles;
};
vector(vector v1, vector v2) CrossProduct = {
  local vector v;
  v_x = v1_y * v2_z - v1_z * v2_y;
  v_y = v1_z * v2_x - v1_x * v2_z;
  v_z = v1_x * v2_y - v1_y * v2_x;
  return v;
};
vector(vector org, vector dir) findnormal = 
{
  local float connect, length = 128;
  local vector angle;
  local vector p1, p2, p3;
  makevectors(dir);
  angle = v_forward * 3 + v_right - v_up * 4;
  angle = normalize(angle);
  traceline(org, org + angle * length, FALSE, world);
  if(trace_fraction == 1)
    connect++;
  p1 = trace_endpos;
  angle = v_forward * 3 - v_right - v_up * 4;
  angle = normalize(angle);
  traceline(org, org + angle * length, FALSE, world);
  if(trace_fraction == 1)
    connect++;
  p2 = trace_endpos;
  angle = '0 0 0' - v_up;
  angle = normalize(angle);
  traceline(org, org + angle * length, FALSE, world);
  p3 = trace_endpos;
  if(connect > 0)
    return;
  //gunshot(p1);gunshot(p2);gunshot(p3);
  p1 -= org;
  p2 -= org;
  p3 -= org;
  return normalize(CrossProduct(p1 - p3, p2 - p3));
};
void() Car = {
  self.car.axis = '0 0 0';
  makevectors(self.car.angles);
  traceline(self.origin, self.origin + v_forward * 64 + v_forward * 32, FALSE, self);
  //if(trace_fraction < 1)
  //  self.car.axis += CrossProduct(v_forward, normalize(self.velocity));
  self.car.axis += CrossProduct(v_up, findnormal(self.origin, self.car.angles)) * 4;
  self.car.axis -= self.movement_z * v_up * 0.01 * cvar("lspeed");
  entrotate(self.car, normalize(self.car.axis), vlen(self.car.axis));
  self.angles = self.car.angles;
  self.fixangle = 1;
  //self.weaponmodel = 0;
  self.velocity_z += cvar("sv_gravity") * frametime;
  makevectors(self.angles);
  traceline(self.origin, self.origin - v_up * 70 + v_forward * 32, FALSE, self);
  
  if(trace_fraction  < 0.5)
    self.velocity += cvar("sv_gravity") * frametime * v_up * (1 - trace_fraction);
  else
    self.velocity -= cvar("sv_gravity") * frametime * v_up * trace_fraction;
};
