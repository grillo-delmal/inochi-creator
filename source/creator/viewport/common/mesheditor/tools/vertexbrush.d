module creator.viewport.common.mesheditor.tools.vertexbrush;

import creator.viewport.common.mesheditor.tools.base;
import creator.viewport.common.mesheditor.operations;
import i18n;
import creator.viewport;
import creator.viewport.common;
import creator.viewport.common.mesh;
import creator.viewport.common.spline;
import creator.core.input;
import creator.core.actionstack;
import creator.actions;
import creator.ext;
import creator.widgets;
import creator;
import inochi2d;
import inochi2d.core.dbg;
import bindbc.opengl;
import bindbc.imgui;
import std.algorithm.mutation;
import std.algorithm.searching;
import std.stdio;
import std.math;


class VertexBrushTool : Tool, Draggable {
    /*
    Settings:
    - inner rad => move 100
    - outer rad => move 0

    Variables
    - mouse_pos
    - last_pos
    */
    float _innerRad = 50;
    float _outerRad = 100;

    vec2 _lastMousePos;

    bool _isDragging = false;

    ulong[] _brushed_verts;

    enum VertexBrushActionID {
        None = 0,
        StartDrag = 1,
        Dragging,
    }

    override bool onDragStart(vec2 mousePos, IncMeshEditorOne impl) {
        _lastMousePos = mousePos;
        if(!_isDragging){
            _isDragging = true;
            impl.getDeformAction();
            return true;
        }
        return false;
    }

    override bool onDragUpdate(vec2 mousePos, IncMeshEditorOne impl) {
        //- on mouse hold
        //- if last pos not null 
        //    - calc diff (last pos - mouse pos)
        //    - apply diff x rad dif to vertex
        bool changed = false;

        vec2 move = mousePos - _lastMousePos;
        if((move.x != 0 || move.y != 0) && _brushed_verts.length > 0){
            auto movable = impl.getVerticesByIndex(_brushed_verts);
            //writefln("moving: %d", movable.length);
            foreach (v; movable) {
                auto dist = inmath.math.abs(v.position.distance(_lastMousePos));

                auto mag = min((_outerRad - dist) / (_outerRad - _innerRad), 1.0f);
                if(mag > 0){
                    //writefln(
                    //    "* moving: %f %f -> %f %f * %f", 
                    //    v.position.x, v.position.y,
                    //    move.x, move.y,
                    //    mag);
                    impl.updateAddVertexAction(v);
                    impl.markActionDirty();
                    v.position += move*mag;

                    changed = true;
                }
            }
            impl.refreshMesh();
        }
        _lastMousePos = mousePos;

        auto implDef = cast(IncMeshEditorOneDrawableDeform) impl;
        if(implDef is null){
            return changed;
        } 

        //- if vertex in outer rad
        //    - add to vetex list, update
        _brushed_verts = implDef.getInCircle(mousePos, _outerRad);
        return changed;
    }

    override bool onDragEnd(vec2 mousePos, IncMeshEditorOne impl) {
        _isDragging = false;
        //- on mouse release
        //    - clear vertex list
        //    - clear last pos = null
        impl.pushDeformAction();
        _brushed_verts = [];

        return true;
    }

    override int peek(ImGuiIO* io, IncMeshEditorOne impl) {
        impl.mousePos = incInputGetMousePosition();

        // Code from select
        vec4 pIn = vec4(-impl.mousePos.x, -impl.mousePos.y, 0, 1);
        mat4 tr = impl.transform.inverse();
        vec4 pOut = tr * pIn;
        impl.mousePos = vec2(pOut.x, pOut.y);

        if (incInputIsMouseReleased(ImGuiMouseButton.Left)) {
            onDragEnd(impl.mousePos, impl);
        }

        if (_isDragging) {
            return VertexBrushActionID.Dragging;
        }

        if (incDragStartedInViewport(ImGuiMouseButton.Left) && igIsMouseDown(ImGuiMouseButton.Left) && incInputIsDragRequested(ImGuiMouseButton.Left)) {
            return VertexBrushActionID.StartDrag;
        }

        return VertexBrushActionID.None;
    }

    override int unify(int[] actions) {
        int action = VertexBrushActionID.None;
        foreach (a; actions) {
            if(action == VertexBrushActionID.None){
                action = a;
                break;
            }
        }
        return action;
    }

    override bool update(ImGuiIO* io, IncMeshEditorOne impl, int action, out bool changed) {
        // Dragging
        if (action == VertexBrushActionID.StartDrag) {
            onDragStart(impl.mousePos, impl);
        }

        if (action == VertexBrushActionID.Dragging){
            changed = onDragUpdate(impl.mousePos, impl) || changed;
        }

        return changed;
    }

    override
    void setToolMode(VertexToolMode toolMode, IncMeshEditorOne impl) {
        _isDragging = false;
    }

    override void draw(Camera camera, IncMeshEditorOne impl) {
        vec4 color = vec4(0.7, 0.2, 0.2, 1);

        if(!_isDragging){
            color = vec4(0.2, 0.9, 0.9, 1);
        }

        vec3[] lines;
        lines ~= incCreateCircleBuffer(
            impl.mousePos, vec2(_innerRad, _innerRad), 32);
        lines ~= incCreateCircleBuffer(
            impl.mousePos, vec2(_outerRad, _outerRad), 32);

        inDbgSetBuffer(lines);
        inDbgDrawLines(color, impl.transform);
   }
}