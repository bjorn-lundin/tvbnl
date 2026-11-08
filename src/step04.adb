-------------------------------------------------------------------------------
-- SPDX-License-Identifier: LGPL-3.0-or-later WITH LGPL-3.0-linking-exception--
-- SPDX-FileCopyrightText:  (C) 2026 Zhu, Qun-Ying <zhu.qunying*gmail.com>   --
--                                                                           --
-- This file is part of AdaVision library.                                 --
-- Copyright (C) 2026  Zhu, Qun-Ying <zhu.qunying*gmail.com>                 --
--                                                                           --
-- This library is free software: you can redistribute it and/or modify it   --
-- under the terms of the GNU Lesser General Public License as published by  --
-- the Free Software Foundation, either version 3 of the License, or         --
-- (at your option) any later version.                                       --
--                                                                           --
-- This library is distributed in the hope that it will be useful, but       --
-- WITHOUT ANY WARRANTY; without even the implied warranty of                --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser   --
-- General Public License for more details.                                  --
--                                                                           --
-- You should have received a copy of the GNU Lesser General Public License  --
-- along with this program. If not, see <https://www.gnu.org/licenses/>.     --
--                                                                           --
-- As a special exception to the GNU Lesser General Public License version   --
-- 3, the copyright holders give you permission to convey a Combined Work    --
-- that links to this library without providing the Minimal Corresponding    --
-- Source or the installation information of sections 4d and 4e.  See        --
-- LGPL-3.0-linking-exception.txt.                                           --
-------------------------------------------------------------------------------

--  Step 4: Adding a window.
--
--  File, New opens a window with a text editor in it, File, Open asks for a
--  file and opens it in a window.  Tile, Cascade, Next and Close already work:
--  the desktop knows how to arrange its windows.

with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded;
with AdaVision.Drivers.Terminal;
with AdaVision.Editors;
with AdaVision.Events;
with AdaVision.File_Dialogs;
with AdaVision.File_Editors;
with AdaVision.Geometry;
with AdaVision.Indicators;
with AdaVision.Menus;
with AdaVision.Message_Boxes;
with AdaVision.Programs;
with AdaVision.Scroll_Bars;
with AdaVision.Status_Lines;
with AdaVision.Themes;
with AdaVision.Views;
with AdaVision.Windows;

procedure Step04 is
   package Latin_1 renames Ada.Characters.Latin_1;
   use AdaVision;
   use type Events.Command_Id;          --  for "+", "-" and "=" on commands
   use type File_Editors.File_Editor_Access;

   Cm_About      : constant Events.Command_Id := 100;
   Cm_Theme_Base : constant Events.Command_Id := 110;      --  110 .. 115

   --  A window for a text file.  It is an ordinary window that also knows its
   --  editor, so that the title can follow the file name.
   type Edit_Window is new Windows.Window with record
      Editor : File_Editors.File_Editor_Access;
   end record;
   
   type Edit_Window_Access is access all Edit_Window;

   overriding function Title (Self : Edit_Window) return String;

   overriding function Title (Self : Edit_Window) return String is
     (if Self.Editor = null or else Self.Editor.File_Name = ""
      then "Untitled" else Self.Editor.File_Name);

   type Tutor_App is new Programs.Application with null record;

   overriding function Create_Menu_Bar
     (Self   : in out Tutor_App;
      Bounds : Geometry.Rect) return Views.View_Access;
   overriding function Create_Status_Line
     (Self   : in out Tutor_App;
      Bounds : Geometry.Rect) return Views.View_Access;
   overriding procedure Handle_Event
     (Self : in out Tutor_App;
      Item : in out Events.Event);

   overriding function Create_Menu_Bar
     (Self   : in out Tutor_App;
      Bounds : Geometry.Rect) return Views.View_Access
   is
      pragma Unreferenced (Self);
      Bar : constant Menus.Menu_Bar_Access := new Menus.Menu_Bar;
   begin
      Bar.Init (Geometry.Make (Bounds.A.X, Bounds.A.Y, Bounds.B.X, Bounds.A.Y + 1));
      Bar.Set_Items
        ([Menus.Sub_Menu ("~F~ile",
            [Menus.Item ("~N~ew", Events.Cm_New, Events.Ctrl_Key ('n')),
             Menus.Item ("~O~pen...", Events.Cm_Open, Events.Key (Events.F3)),
             Menus.Separator,
             Menus.Item ("E~x~it", Events.Cm_Quit, Events.Alt_Key ('x'))]),
          Menus.Sub_Menu ("~W~indows",
            [Menus.Item ("~T~ile", Events.Cm_Tile),
             Menus.Item ("C~a~scade", Events.Cm_Cascade),
             Menus.Item ("~N~ext", Events.Cm_Next, Events.Key (Events.F6)),
             Menus.Item ("~C~lose", Events.Cm_Close,
                         Events.Key (Events.F3, (Alt => True, others => False)))]),
          Menus.Sub_Menu ("~O~ptions",
            [Menus.Item ("~C~lassic", Cm_Theme_Base),
             Menus.Item ("~D~ark", Cm_Theme_Base + 1),
             Menus.Item ("~L~ight", Cm_Theme_Base + 2),
             Menus.Item ("~M~ono", Cm_Theme_Base + 3),
             Menus.Item ("~A~mber", Cm_Theme_Base + 4),
             Menus.Item ("~G~reen", Cm_Theme_Base + 5)]),
          Menus.Sub_Menu ("~H~elp",
            [Menus.Item ("~A~bout...", Cm_About)])]);
      return Views.View_Access (Bar);
   end Create_Menu_Bar;

   overriding function Create_Status_Line
     (Self   : in out Tutor_App;
      Bounds : Geometry.Rect) return Views.View_Access
   is
      pragma Unreferenced (Self);
      Line : constant Status_Lines.Status_Line_Access := new Status_Lines.Status_Line;
   begin
      Line.Init (Geometry.Make (Bounds.A.X, Bounds.B.Y - 1, Bounds.B.X, Bounds.B.Y));
      Line.Add_Definition
        ([Status_Lines.Item ("~F3~ Open", Events.Key (Events.F3), Events.Cm_Open),
          Status_Lines.Item ("~F6~ Next", Events.Key (Events.F6), Events.Cm_Next),
          Status_Lines.Item ("~F10~ Menu", Events.Key (Events.F10), Events.Cm_Menu),
          Status_Lines.Item ("~Alt-X~ Exit", Events.Alt_Key ('x'), Events.Cm_Quit)]);
      return Views.View_Access (Line);
   end Create_Status_Line;

   --  Makes a window on the desktop.  Name is the file to show; "" is a new,
   --  empty one.
   procedure Open_Editor (Self : in out Tutor_App; Name : String) is
      Win  : constant Edit_Window_Access := new Edit_Window;
      Area : Geometry.Rect;
      V, H : Scroll_Bars.Scroll_Bar_Access;
      Mark : constant Indicators.Indicator_Access := new Indicators.Indicator;
   begin
      Win.Init (Self.Desktop.Extent, "", 0);                  --  no number
      Area := Win.Extent;
      V := Win.Standard_Scroll_Bar (True);
      H := Win.Standard_Scroll_Bar (False);
      Win.Editor := new File_Editors.File_Editor;
      Win.Editor.Init (Geometry.Make (Area.A.X + 1, Area.A.Y + 1, Area.B.X - 1, Area.B.Y - 1));
      Win.Insert (Win.Editor.Handle_Of);
      Win.Editor.Set_Bars (H, V);
      Mark.Init (Geometry.Make (Area.A.X + 2, Area.B.Y - 1, Area.A.X + 14, Area.B.Y),
                 Editors.Editor_Access (Win.Editor));
      Win.Insert (Mark.Handle_Of);
      if Name /= "" and then not Win.Editor.Load (Name) then
         Win.Editor.Set_File_Name (Name);                    --  a file to be created
      end if;
      Self.Desktop.Insert (Win.Handle_Of);
   end Open_Editor;

   overriding procedure Handle_Event
     (Self : in out Tutor_App;
      Item : in out Events.Event)
   is
      use type Events.Event_Kind;
   begin
      --  the inherited handler does Cm_Quit, Cm_Tile, Cm_Cascade, the menus ...
      Programs.Application (Self).Handle_Event (Item);
      if Item.Kind /= Events.Command then
         return;
      end if;
      if Item.Id = Cm_About then
         declare
            Ignore : constant Events.Command_Id := Message_Boxes.Message_Box
              ("AdaVision tutorial" & Latin_1.LF & "Step 3", Message_Boxes.Information);
         begin
            null;
         end;
      elsif Item.Id = Events.Cm_New then
         Open_Editor (Self, "");
      elsif Item.Id = Events.Cm_Open then
         declare
            Path : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if File_Dialogs.Choose ("Open file", "*", "", File_Dialogs.Open_File, Path, 100)
              = Events.Cm_OK
            then
               Open_Editor (Self, Ada.Strings.Unbounded.To_String (Path));
            end if;
         end;
      elsif Item.Id in Cm_Theme_Base .. Cm_Theme_Base + 5 then
         Themes.Set_Current
           (Themes.Builtin (case Item.Id - Cm_Theme_Base is
                               when 0 => "classic", when 1 => "dark", when 2 => "light",
                               when 3 => "mono", when 4 => "amber",
                               when others => "dark_green"));
      else
         return;                              --  not ours: leave the event alone
      end if;
      Self.Clear_Event (Item);                --  ours, and done
   end Handle_Event;

   Display : aliased Drivers.Terminal.Terminal_Driver;
   App     : Tutor_App;
begin
   App.Init (Display'Unrestricted_Access);
   App.Run;
end Step04;
