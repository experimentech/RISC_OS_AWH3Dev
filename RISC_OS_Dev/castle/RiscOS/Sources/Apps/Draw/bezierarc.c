/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/* ->  c.BezierArc
 *
 * Construct bezier curves from arcs
 *
 * Author: David Elworthy
 * Version: 0.10
 * History: 0.00 - 18 July 1988 - created
 *          0.10 - 19 July 1988
 *                 12 June 1989 - header added
 *
 * Based on ideas by David Seal. Ask him about the hard bits.
 *
 * The 'maximum angle' is the longest chunk we want implemented as a single
 * path element. This is assumed to be 90 degrees.
 *
 * All coordinates, radii and centres are passed in draw units, generally as
 * coordinate structures.
 * All angles are passed in radians, in double format.
 * Internal computation is done in doubles.
 *
 * Note that arcs which have start and end angles very close together will
 * appear as circles. This only happens when the difference in angles is less
 * than about 1e-12 degrees.
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "os.h"
#include "bezierarc.h"

/* Useful constants for 90 degree arcs */
#define bezierarc_k90   (0.552284750)
   /* 4 * (sqrt(2) - 1) / 3 */
#define bezierarc_cos45 (0.707106781)
   /* 1/sqrt(2) */

/*
 Function    : bezierarc_short
 Purpose     : calculate bezier points for an arc of less than 90 degrees
 Parameters  : centre of arc
               start angle
               end angle
               radius
               OUT: start point
                    end point
                    bezier control point 1
                    bezier control point 2
 Returns     : void
 Description : the bezier control points are calculated as follows:
  1. Conceptually centre the arc on 0,0; the end points are defined to
     be (X1, Y1), (X2, Y2) in this coordinate system. X1, X2, Y1, Y2 can be
     calculated from the parameters.
  2. The control points are then (X1-k.Y1, Y1+k.X1) and (X2+k.Y2, Y2-k.X2)
     where k is a positive constant obtained from:

     k = 4(SQR(2.(X1^2 + Y1^2).(X1^2 + Y1^2 + X1.X2 + Y1.Y2))
               - (X1^2 + Y1^2 + X1.X2 + Y1.Y2)) / 3(X1.Y2 - Y1.X2)
  3. Having obtained these control points, shift back to the true origin.
     (x1, y1) and (x2, y2) are returned as the start and end points

 Note that there is no check that the angle is less than the maximum.
*/

void bezierarc_short(bezierarc_coord centre, double startAngle, double endAngle,
                     int radius,
                     bezierarc_coord *start, bezierarc_coord *end,
                     bezierarc_coord *control1, bezierarc_coord *control2)
{
    double x1, y1, x2, y2;
    double k;

    /* Calculate end points, based on (0,0) */
    x1 = radius * cos(startAngle);
    y1 = radius * sin(startAngle);
    x2 = radius * cos(endAngle);
    y2 = radius * sin(endAngle);

    /* Record start and end locations */
    start->x = centre.x + (int)x1;
    start->y = centre.y + (int)y1;
    end->x   = centre.x + (int)x2;
    end->y   = centre.y + (int)y2;

    /* Calculate k */
    {
        double x1sq_plus_y1sq;
        double sq_plus_x1x2_plus_y1y2;

        x1sq_plus_y1sq = x1*x1 + y1*y1;
        sq_plus_x1x2_plus_y1y2 = x1sq_plus_y1sq + x1*x2 + y1*y2;
        k = 4 * (sqrt(2 * x1sq_plus_y1sq * sq_plus_x1x2_plus_y1y2)
                      - sq_plus_x1x2_plus_y1y2) / (3 * (x1*y2 - y1*x2));
    }

    /* Find control points, including origin shift */
    control1->x = (int)(centre.x + x1 - k * y1);
    control1->y = (int)(centre.y + y1 + k * x1);
    control2->x = (int)(centre.x + x2 + k * y2);
    control2->y = (int)(centre.y + y2 - k * x2);
}

/*
 Function    : bezierarc_90
 Purpose     : find bezier control points for 90 degree arc
 Parameters  : centre of arc
               start angle of arc
               radius
               OUT: start point
                    end point
                    bezier control point 1
                    bezier control point 2
 Returns     : void
 Description : the control points are calculated as follows:
   1. Conceptually shift the centre to (0,0). The arc then runs from (X, Y) to
      (Y, -X), which can be found from the radius and start angle.
   2. Calculate the bezier control points as (X-kY, Y+kX) and (kX-Y, kY+X)
      where k = 4(SQR(2)-1)/3 [precalculated]
   3. Shift the control points to allow for the actual centre.
      The shifted versions of (X, Y) and (Y, -X) are returned as the start and
      end points.

   Note: when the arc is already axis aligned and centred on (0,0), use
         bezierarc_90_aligned instead.
*/

void bezierarc_90(bezierarc_coord centre, double startAngle, int radius,
                  bezierarc_coord *start, bezierarc_coord *end,
                  bezierarc_coord *control1, bezierarc_coord *control2)
{
    double x, y, kx, ky;

    /* Calculate X and Y, and multiples needed for Bezier */
    x = radius * cos(startAngle);
    y = radius * sin(startAngle);
    kx = bezierarc_k90 * x;
    ky = bezierarc_k90 * y;

    /* Find control points and end points, applying origin shift */
    start->x = centre.x + (int)x;
    start->y = centre.y + (int)y;
    end->x   = centre.x + (int)(-y);
    end->y   = centre.y + (int)x;
    control1->x = (int)(centre.x + x  - ky);
    control1->y = (int)(centre.y + y  + kx);
    control2->x = (int)(centre.x + kx -  y);
    control2->y = (int)(centre.y + ky +  x);
}

/*
 Function    : bezierarc_90_aligned
 Purpose     : draw a centred 90 degress arc, axis aligned
 Parameters  : radius
               OUT: start point
                    end   point
                    bezier control point 1
                    bezier control point 2
 Returns     : void
 Description : this is used to draw a 90 degree arc, centred on the positive
               y axis, with the arc centre at (0,0). Its main use is in drawing
               circles. The method is essentially that of bezierarc_90, but
               with some calculations taken out. The start angle is taken as
               45 degrees, so it has a cos of 1/SQR(2) and a sine of 1/SQR(2).

               The start and end points are then (x,y) and (-x,y) [x=y].

               Since x = y (and hence kx = ky), the control points simplify to
               (x-kx, x+kx) and (kx-x), (kx+x)
*/

static void bezierarc_90_aligned(int radius, 
                                 bezierarc_coord *start, bezierarc_coord *end,
                                 bezierarc_coord *control1, bezierarc_coord *control2)
{
    double x, kx;
    int    ix;

    /* Calculate X, and multiple needed for Bezier */
    x  = radius * bezierarc_cos45;
    kx = bezierarc_k90 * x;

    /* Find control points and end points, applying origin shift */
    start->x = ix = (int)x;
    start->y = ix;
    end->x   = -ix;
    end->y   = ix;
    control1->x = (int)(x - kx);
    control1->y = (int)(x + kx);
    control2->x = -control1->x;
    control2->y =  control1->y;
}

/*
 Function    : bezierarc_circle
 Purpose     : draw a complete circle
 Parameters  : centre
               radius
               OUT: point buffer (see below)
 Returns     : void
 Description : generates a circle as four arcs of 90 degree each. These are
               placed in a point buffer, implemented as an array of coords,
               which is to be used as follows:
               move to point 0
               curve to 1, 2, 3 (i.e. 1,2 are control, 3 is end)
               curve to 4, 5, 6
               curve to 7, 8, 9
               curve to 10, 11, 12
               The buffer thus needs to be large enough for 13 coordinates.

   To get the points, we proceed as follows: find the control points and start
   and end points for an axis aligned arc based on (0,0).
   The buffer points are then generated by applying centre shifts to the
   points generated, as follows:
    let (a, b) be control point 1 [control point 2 will be (-a,b)]
    let (s, t) be start point [end point will be (-s, s), s = t]
    point 0  = start
    point 1  = (a,b),   point 2  = (-a,b)
    point 3  = end [(-s, s)]
    point 4  = (-b,a),  point 5  = (-b,-a)
    point 6  = (-s,-s)
    point 7  = (-a,-b), point 8  = (a,-b)
    point 9  = (s,-s)
    point 10 = (b,-a),  point 11 = (b,a)
    point 12 = point 0
*/

void bezierarc_circle(bezierarc_coord centre, int radius, bezierarc_coord *p)
{
    bezierarc_coord start, end, control1, control2;

    /* Get initial parameters */
    bezierarc_90_aligned(radius, &start, &end, &control1, &control2);

    /* Calculate points adding centre shifts */
    p[0].x  = p[9].x  = centre.x + start.x;
    p[0].y  = p[3].y  = centre.y + start.y;
    p[3].x  = p[6].x  = centre.x - start.x;
    p[6].y  = p[9].y  = centre.y - start.y;

    p[1].x  = p[8].x  = centre.x + control1.x;
    p[2].x  = p[7].x  = centre.x - control1.x;
    p[4].y  = p[11].y = centre.y + control1.x;
    p[5].y  = p[10].y = centre.y - control1.x;
    p[10].x = p[11].x = centre.x + control1.y;
    p[4].x  = p[5].x  = centre.x - control1.y;
    p[1].y  = p[2].y  = centre.y + control1.y;
    p[7].y  = p[8].y  = centre.y - control1.y;

    p[12] = p[0];
}

/*
 Data Group  : static variables used in arc drawing
 Description :
*/

static double bezierarc__angle;            /* Current angle */
static int    bezierarc__segments;         /* Number of segments */
static bezierarc_coord bezierarc__centre; /* Centre of arc */
static int    bezierarc__radius;           /* Radius of arc */

/*
 Function    : bezierarc_start
 Purpose     : start to draw an arc
 Parameters  : centre
               start angle
               end angle
               radius
               OUT: start, end, control1, control2 points
 Returns     : number of segments including this one
 Description : calculates the start, and and control points for the first
               segment of an arc. This should be followed by repeated
               calls to bezierarc_segment.
               Only one arc may be in progress at a time.
               The number of segments can be used for (e.g.) assigning
               memory for the path.
*/

int  bezierarc_start(bezierarc_coord centre,
                    double startAngle, double endAngle,
                    int radius,
                    bezierarc_coord *start,   bezierarc_coord *end,
                    bezierarc_coord *bezier1, bezierarc_coord *bezier2)
{
    bezierarc__segments = (endAngle > startAngle) ?
        (int)floor((endAngle-startAngle)/bezierarc_rad90) :
        (int)floor((bezierarc_rad360+endAngle-startAngle) / bezierarc_rad90);

    /* Find end of short segment */
    endAngle  -= bezierarc__segments * bezierarc_rad90;

    /* Check for a zero length arc */
    if (startAngle == endAngle)
    {
        /* Find arc points for first 90 degree chunk */
        bezierarc_90(centre, startAngle, radius, start, end, bezier1,bezier2);
        endAngle += bezierarc_rad90;
    }
    else
    {
        /* Find arc points for first chunk of arc */
        bezierarc_short(centre, startAngle, endAngle, radius,
                       start, end, bezier1, bezier2);
        bezierarc__segments += 1;
    }

    /* Record iterator globals */
    bezierarc__angle  = endAngle;
    bezierarc__centre = centre;
    bezierarc__radius = radius;

    return (bezierarc__segments);
}

/*
 Function    : bezierarc_segment
 Purpose     : draw next segment of an arc
 Parameters  : segment number
               OUT: end, control1, control2 points
 Returns     : next segment number
 Description : this should be called repeatedly, following bezierarc_start.
               On the first call, the segment number should be 1, and
               thereafter it should be the segment number returned by the
               previous call.
               The routine returns zero when next called after the last
               segment has been drawn.
*/

int  bezierarc_segment(int segment, bezierarc_coord *end,
                        bezierarc_coord *bezier1, bezierarc_coord *bezier2)
{
    bezierarc_coord start;           /* Dummy needed for start */

    if (segment <= 0 || segment == bezierarc__segments)
        return (0);

    /* Calculate arc */
    bezierarc_90(bezierarc__centre, bezierarc__angle, bezierarc__radius,
                      &start, end, bezier1, bezier2);

    /* Next angle */
    bezierarc__angle += bezierarc_rad90;

    return (segment+1);
}
