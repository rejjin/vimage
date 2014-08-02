/*
 * File   : TkImageTools.cxx
 * Purpose: Resize and other image related tools
 *
 * Author : Tom Wilkason
 * Dated  : 12/22/2005

 * From SnackAMP: http://snackamp.sourceforge.net
 * Original url: http://snackamp.sourceforge.net/releases/tkImageTools.zip
*/

#include <stdio.h>
#include <tcl.h>
#include <tk.h>

static int imageResize  (ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);

extern int createTkCommands(Tcl_Interp *interp);

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT

EXTERN int Tkimagetools_Init(Tcl_Interp *interp)

{
   #if TCL_MAJOR_VERSION == 8 && TCL_MINOR_VERSION >= 1
   // use stubs when possible
   if (Tcl_InitStubs(interp, "8.1", 0) == NULL) {
     return TCL_ERROR;
   }
   if (Tk_InitStubs(interp, "8.1", 0) == NULL) {
     return TCL_ERROR;
   }
   #endif

   if ( Tcl_PkgProvide(interp, "TkImageTools", "1.0") != TCL_OK )
   {
      return TCL_ERROR;
   }
   createTkCommands(interp);
   Tcl_AppendResult(interp,"TkImageTools 1.0 Ready",NULL);

   return 0;
}

int createTkCommands(Tcl_Interp *interp)
{
   Tcl_CreateObjCommand(interp, "tkImageTools::resize", imageResize, 
        (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);
   return 1;
}

int
  ScalePhotoBlock (
                  Tcl_Interp *interp,
                  Tk_PhotoImageBlock *srcBlockPtr,
                  Tk_PhotoImageBlock *dstBlockPtr,
                  int newcols,
                  int newrows)
{
#define SCALE      4096
#define HALFSCALE  2048
#define MAXPIXVAL  255
   unsigned char *xelrow;
   unsigned char *tempxelrow;
   unsigned char *newimage;
   unsigned char *newxelrow;
   register unsigned char *xP;
   register unsigned char *nxP;
   int rows, cols, srcrow, bpp;
   register int row, col, needtoreadrow, p;
   double xscale, yscale;
   long   sxscale, syscale;
   register long fracrowtofill, fracrowleft;
   long  *pixarray[4], v;
   int pitch, newpitch;

   cols    = srcBlockPtr->width;
   rows    = srcBlockPtr->height;
   bpp     = srcBlockPtr->pixelSize;
   xscale = (double) newcols / cols;
   yscale = (double) newrows / rows;
   sxscale = (long) (xscale * SCALE);
   syscale = (long) (yscale * SCALE);

   pitch = srcBlockPtr->pitch;
   newpitch = newcols*bpp;

   if (newrows != rows)
   {
      tempxelrow = (unsigned char*) Tcl_AttemptAlloc(bpp*cols);
      if (!tempxelrow)
      {
         Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
         return TCL_ERROR;
      }
   } else
   {
      tempxelrow = 0;
   }
   pixarray[0] = (long*) Tcl_AttemptAlloc(bpp*cols*sizeof(long));
   if (!pixarray[0])
   {
      if (tempxelrow)
         Tcl_Free((char*) tempxelrow);
      Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
      return TCL_ERROR;
   }
   pixarray[1] = pixarray[0] + cols;
   pixarray[2] = pixarray[1] + cols;
   pixarray[3] = pixarray[2] + cols;
   for (p = 0; p < bpp; ++p)
   {
      for (col = 0; col < cols; ++col)
         pixarray[p][col] = HALFSCALE;
   }

   fracrowleft   = syscale;
   needtoreadrow = 1;
   fracrowtofill = SCALE;

   newimage = (unsigned char*) Tcl_AttemptAlloc(newcols * newrows * bpp);
   if (!newimage)
   {
      if (newrows != rows)
         Tcl_Free((char*) tempxelrow);
      Tcl_Free((char*) pixarray[0]);
      Tcl_SetResult(interp, "couldn't allocate image", TCL_STATIC);
      return TCL_ERROR;
   }
   newxelrow = newimage;
   xelrow = 0;
   for (row = 0, srcrow = 0; row < newrows; ++row)
   {
        /* First scale Y from xelrow into tempxelrow. */
      if (newrows == rows)  /* shortcut Y scaling if possible */
      {
         tempxelrow = xelrow = srcBlockPtr->pixelPtr + (pitch * srcrow++);
      } else
      {
         while (fracrowleft < fracrowtofill)
         {
            if (needtoreadrow && srcrow < rows)
               xelrow = srcBlockPtr->pixelPtr + (pitch * srcrow++);
            for (col = 0, xP = xelrow; col < cols; ++col)
               for (p = 0; p < bpp; ++p, ++xP)
                  pixarray[p][col] += fracrowleft * *xP;
            fracrowtofill -= fracrowleft;
            fracrowleft = syscale;
            needtoreadrow = 1;
         }

            /* Now fracrowleft is >= fracrowtofill, so we can produce a row. */
         if (needtoreadrow && srcrow < rows)
         {
            xelrow = srcBlockPtr->pixelPtr + (pitch * srcrow++);
            needtoreadrow = 0;
         }
         for (col = 0, xP = xelrow, nxP = tempxelrow; col < cols; ++col)
         {
            for (p = 0; p < bpp; ++p, ++xP, ++nxP)
            {
               v = (pixarray[p][col] + fracrowtofill * *xP) / SCALE;
               *nxP = (unsigned char) (v > MAXPIXVAL ? MAXPIXVAL:v);
               pixarray[p][col] = HALFSCALE;
            }
         }
         fracrowleft -= fracrowtofill;
         if (fracrowleft == 0)
         {
            fracrowleft = syscale;
            needtoreadrow = 1;
         }
         fracrowtofill = SCALE;
      }


        /* Now scale X from tempxelrow into newxelrow and write it out. */
      if (newcols == cols)  /* shortcut X scaling if possible */
      {
         for (col = 0, xP = tempxelrow, nxP = newxelrow; col < cols; ++col)
            for (p = 0; p < bpp; ++p, ++xP, ++nxP)
               *nxP = *xP;
         newxelrow = newxelrow + newpitch;
      } else
      {
         long pixval[4];
         register long fraccoltofill, fraccolleft;
         register int needcol;

         nxP = newxelrow;
         fraccoltofill = SCALE;
         for (p = 0; p < bpp; ++p)
            pixval[p] = HALFSCALE;
         needcol = 0;
         for (col = 0, xP = tempxelrow; col < cols; ++col, xP += bpp)
         {
            fraccolleft = sxscale;
            while (fraccolleft >= fraccoltofill)
            {
               if (needcol)
               {
                  nxP += bpp;
                  for (p = 0; p < bpp; ++p)
                     pixval[p] = HALFSCALE;
               }
               for (p = 0; p < bpp; ++p)
               {
                  pixval[p] = (pixval[p] + fraccoltofill * xP[p]) / SCALE;
                  if (pixval[p] > MAXPIXVAL) pixval[p] = MAXPIXVAL;
                  nxP[p]    = (unsigned char) pixval[p];
               }
               fraccolleft  -= fraccoltofill;
               fraccoltofill = SCALE;
               needcol = 1;
            }
            if (fraccolleft > 0)
            {
               if (needcol)
               {
                  nxP += bpp;
                  for (p = 0; p < bpp; ++p)
                     pixval[p] = HALFSCALE;
                  needcol = 0;
               }
               for (p = 0; p < bpp; ++p)
                  pixval[p] += fraccolleft * xP[p];
               fraccoltofill -= fraccolleft;
            }
         }
         if (fraccoltofill > 0)
         {
            xP -= bpp;
            for (p = 0; p < bpp; ++p)
               pixval[p] += fraccoltofill * xP[p];
         }
         if (!needcol)
         {
            for (p = 0; p < bpp; ++p)
            {
               pixval[p] /= SCALE;
               if (pixval[p] > MAXPIXVAL) pixval[p] = MAXPIXVAL;
               nxP[p] = (unsigned char) pixval[p];
            }
         }
         newxelrow = newxelrow + newpitch;
      }
   }

   Tcl_Free((char*) pixarray[0]);
   if (newrows != rows)
      Tcl_Free((char*) tempxelrow);

   dstBlockPtr->width = newcols;
   dstBlockPtr->height = newrows;
   dstBlockPtr->pixelSize = bpp;
   dstBlockPtr->pitch = newpitch;
   dstBlockPtr->pixelPtr = newimage;
   dstBlockPtr->offset[0] = 0;
   dstBlockPtr->offset[1] = 1;
   dstBlockPtr->offset[2] = 2;
   dstBlockPtr->offset[3] = 3;

   return TCL_OK;

#undef SCALE
#undef HALFSCALE
#undef MAXPIXVAL
}

static int imageResize (
  ClientData clientData,
  Tcl_Interp *interp,
  int objc,
  Tcl_Obj *CONST objv[]
  )
{

   if (objc < 5)
   {
      Tcl_WrongNumArgs(interp, 1, objv, "sourceImg destImg newRows newCols");
      return TCL_ERROR;
   }
   
   int result;
   char *src, *dest;
   
   Tk_PhotoHandle sp, dp;
   Tk_PhotoImageBlock sb, db;
   
   int newrows=1;
   int newcols=1;
   
   src = Tcl_GetString(objv[1]);
   dest = Tcl_GetString(objv[2]);
   
   Tcl_GetIntFromObj(interp,objv[3],&newrows);
   Tcl_GetIntFromObj(interp,objv[4],&newcols);
   
   sp = Tk_FindPhoto(interp, src );
   dp = Tk_FindPhoto(interp, dest);
   
   if (sp==0)
   {
      Tcl_AppendResult (interp, "Invalid image source specified",NULL);
      return TCL_ERROR;
   } else if (dp==0)
   {
      Tcl_AppendResult (interp, "Invalid image destination specified",NULL);
      return TCL_ERROR;
   }
   
   db.pixelPtr = 0;
   
   Tk_PhotoGetImage(sp, &sb);
   Tk_PhotoGetImage(dp, &db);
   
   result = ScalePhotoBlock(interp,&sb,&db,newrows,newcols);
   
   if (result == TCL_OK)
   {
      Tk_PhotoPutBlock(interp, dp, &db, 0, 0, newrows, newcols, TK_PHOTO_COMPOSITE_OVERLAY);
      
      if (db.pixelPtr)
         Tcl_Free((char *)db.pixelPtr);
         
      return TCL_OK;
   } 
   else return result;
}
