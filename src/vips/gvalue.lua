-- manipulate GValue objects from lua
-- pull in gobject via the vips library

local ffi = require "ffi" 

local log = require "vips/log" 

local vips = ffi.load("vips")

ffi.cdef[[
    typedef struct _GValue {
        unsigned long int type;
        uint64_t data[2]; 
    } GValue;

    typedef struct _VipsImage VipsImage;

    void vips_init (const char* argv0);

    void g_value_init (GValue* value, unsigned long int type);
    void g_value_unset (GValue* value);
    const char* g_type_name (unsigned long int type);
    unsigned long int g_type_from_name (const char* name);
    unsigned long int g_type_fundamental (unsigned long int gtype);

    void g_value_set_int (GValue* value, int i);
    void g_value_set_double (GValue* value, double d);
    void g_value_set_enum (GValue* value, int e);
    void g_value_set_flags (GValue* value, unsigned int f);
    void g_value_set_string (GValue* value, const char *str);
    void g_value_set_object (GValue* value, void* object);
    void vips_value_set_array_double (GValue* value, 
        const double* array, int n );
    void vips_value_set_array_int (GValue* value, 
        const int* array, int n );

    int g_value_get_int (GValue* value);
    double g_value_get_double (GValue* value);
    int g_value_get_enum (GValue* value);
    unsigned int g_value_get_flags (GValue* value);
    const char* g_value_get_string (GValue* value);
    void* g_value_get_object (GValue* value);
    double* vips_value_get_array_double (const GValue* value, int* n);
    int* vips_value_get_array_int (const GValue* value, int* n);

]]

-- this will add the vips types as well
vips.vips_init("")

local gvalue
local gvalue_mt = {
    __gc = function(gv)
        log.msg("freeing gvalue ", gv)
        log.msg("  type name =", ffi.string(vips.g_type_name(gv.type)))

        vips.g_value_unset(gv)
    end,

    __index = {
        -- make ffi constructors we can reuse
        gv_typeof = ffi.typeof("GValue"),
        pgv_typeof = ffi.typeof("GValue[1]"),
        image_typeof = ffi.typeof("VipsImage*"),
        pint_typeof = ffi.typeof("int[?]"),
        pdouble_typeof = ffi.typeof("double[?]"),

        -- look up some common gtypes at init for speed
        gint_type = vips.g_type_from_name("gint"),
        gdouble_type = vips.g_type_from_name("gdouble"),
        gstr_type = vips.g_type_from_name("gchararray"),
        genum_type = vips.g_type_from_name("GEnum"),
        gflags_type = vips.g_type_from_name("GFlags"),
        image_type = vips.g_type_from_name("VipsImage"),
        array_double_type = vips.g_type_from_name("VipsArrayDouble"),
        array_int_type = vips.g_type_from_name("VipsArrayInt"),

        new = function()
            -- with no init, this will initialize with 0, which is what we need
            -- for a blank GValue
            local gv = ffi.new(gvalue.gv_typeof)
            log.msg("allocating gvalue", gv)
            return gv
        end,

        newp = function()
            local pgv = ffi.new(gvalue.pgv_typeof)
            log.msg("allocating one-element array of gvalue", pgv)
            return pgv
        end,

        type_name = function(gtype)
            return(ffi.string(vips.g_type_name(gtype)))
        end,

        init = function(gv, gtype)
            log.msg("starting init")
            log.msg("  gv =", gv)
            log.msg("  type name =", gvalue.type_name(gtype))
            vips.g_value_init(gv, gtype)
        end,

        set = function(gv, value)
            log.msg("set() value =")
            log.msg_r(value)

            local gtype = gv.type
            local fundamental = vips.g_type_fundamental(gtype)

            if gtype == gvalue.gint_type then
                vips.g_value_set_int(gv, value)
            elseif gtype == gvalue.gdouble_type then
                vips.g_value_set_double(gv, value)
            elseif fundamental == gvalue.genum_type then
                vips.g_value_set_enum(gv, value)
            elseif fundamental == gvalue.gflags_type then
                vips.g_value_set_flags(gv, value)
            elseif gtype == gvalue.gstr_type then
                vips.g_value_set_string(gv, value)
            elseif gtype == gvalue.image_type then
                vips.g_value_set_object(gv, value)
            elseif gtype == gvalue.array_double_type then
                local n = #value
                local a = ffi.new(gvalue.pdouble_typeof, n, value)

                vips.vips_value_set_array_double(gv, a, n)
            elseif gtype == gvalue.array_int_type then
                local n = #value
                local a = ffi.new(gvalue.pint_typeof, n, value)

                vips.vips_value_set_array_int(gv, a, n)
            else
                 error("unsupported gtype " .. gvalue.type_name(gtype))
            end
        end,

        get = function(gv)
            local gtype = gv.type
            local fundamental = vips.g_type_fundamental(gtype)

            local result

            if gtype == gvalue.gint_type then
                result = vips.g_value_get_int(gv)
            elseif gtype == gvalue.gdouble_type then
                result = vips.g_value_get_double(gv)
            elseif fundamental == gvalue.genum_type then
                result = vips.g_value_get_enum(gv)
            elseif fundamental == gvalue.gflags_type then
                result = vips.g_value_get_flags(gv)
            elseif gtype == gvalue.gstr_type then
                result = ffi.string(vips.g_value_get_string(gv))
            elseif gtype == gvalue.image_type then
                result = ffi.cast(gvalue.image_typeof, 
                    vips.g_value_get_object(gv))
            elseif gtype == gvalue.array_double_type then
                local pint = ffi.new(gvalue.pint_typeof, 1)

                array = vips.vips_value_get_array_double(gv, pint)
                result = {}
                for i = 0, pint[0] - 1 do
                    result[i + 1] = array[i]
                end
            elseif gtype == gvalue.array_int_type then
                local pint = ffi.new(gvalue.pint_typeof, 1)

                array = vips.vips_value_get_array_int(gv, pint)
                result = {}
                for i = 0, pint[0] - 1 do
                    result[i + 1] = array[i]
                end
            else
                 error("unsupported gtype " .. gvalue.type_name(gtype))
            end

            log.msg("get() result =")
            log.msg_r(result)

            return result
        end,

    }
}

gvalue = ffi.metatype("GValue", gvalue_mt)
return gvalue