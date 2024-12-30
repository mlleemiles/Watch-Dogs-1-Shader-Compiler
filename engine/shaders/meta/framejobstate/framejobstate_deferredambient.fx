technique t0
{
    pass p0
    {

        #ifdef INTERIOR
         
            #ifdef STENCILTAG

                HiStencilRef = 1;   
             
            #else

                // Equal is the default, so only need to specify here.
                HiStencilFunc = NotEqual; 
                HiStencilRef = 0;

            #endif

        #else

            HiStencilRef = 0;            

        #endif

    }
} 
